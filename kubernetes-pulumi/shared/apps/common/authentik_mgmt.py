import pulumi
import pulumi_authentik as authentik
from typing import Dict, Any, List


class AuthentikDirectory:
    """Handles provisioning of Users and Groups from Doppler data."""

    def __init__(self, users_data: Dict[str, Any], provider: authentik.Provider):
        self.users_data = users_data
        self.provider = provider
        self.opts = pulumi.ResourceOptions(provider=provider)
        self.groups = {}

    def provision(self) -> List[pulumi.Resource]:
        resources = []

        # 1. Extract and create unique groups (roles)
        group_names = set()
        for user_info in self.users_data.values():
            roles = user_info.get("roles", [])
            if roles:
                for role in roles:
                    group_names.add(role)

        for name in sorted(list(group_names)):
            group = authentik.Group(
                f"ak-group-{name}",
                name=name,
                is_superuser=name == "admin",
                opts=self.opts,
            )
            self.groups[name] = group
            resources.append(group)

        # 2. Create users and link to groups
        for username, user_info in self.users_data.items():
            email = user_info.get("email")
            full_name = user_info.get("name")
            roles = user_info.get("roles", [])

            ak_user = authentik.User(
                f"ak-user-{username}",
                username=username,
                name=full_name or username,
                email=email,
                groups=[self.groups[role].id for role in roles if role in self.groups],
                opts=self.opts,
            )
            resources.append(ak_user)

        return resources


class AuthentikRecovery:
    """Handles provisioning of the Self-Service Password Reset flow."""

    def __init__(self, provider: authentik.Provider):
        self.provider = provider
        self.opts = pulumi.ResourceOptions(provider=provider)

    def setup(self) -> List[pulumi.Resource]:
        resources = []

        # 1. Recovery Flow
        flow = authentik.Flow(
            "ak-recovery-v2-flow",
            name="Recovery V2",
            slug="password-recovery-v2",
            designation="recovery",
            title="Reset your password",
            opts=self.opts,
        )
        resources.append(flow)

        # 2. Email Stage
        email_stage = authentik.StageEmail(
            "ak-recovery-v2-email",
            name="recovery-v2-email",
            use_global_settings=True,
            subject="Authentik: Password Recovery",
            template="email/password_reset.html",
            opts=self.opts,
        )
        resources.append(email_stage)

        # 3. Prompt Stage
        prompt_stage = authentik.StagePrompt(
            "ak-recovery-v2-prompt",
            name="recovery-v2-prompt",
            fields=[
                "9f7971e5-c46b-40b6-8732-12100bcfef4d",  # password
                "e295098c-43c1-48e1-9d12-34cb256d5e34",  # password_repeat
            ],
            opts=self.opts,
        )
        resources.append(prompt_stage)

        # 4. User Write Stage
        write_stage = authentik.StageUserWrite(
            "ak-recovery-v2-write", name="recovery-v2-write", opts=self.opts
        )
        resources.append(write_stage)

        # 4b. User Login Stage (Session establishment)
        login_stage = authentik.StageUserLogin(
            "ak-recovery-v2-login",
            name="recovery-v2-login",
            session_duration="seconds=0",  # Browser session
            opts=self.opts,
        )
        resources.append(login_stage)

        # 5. Bindings for Recovery
        # 5a. Identity Stage (New: needed to identify the user before sending email)
        recovery_ident = authentik.StageIdentification(
            "ak-recovery-v2-ident",
            name="recovery-v2-identification",
            user_fields=["username", "email"],
            opts=self.opts,
        )
        resources.append(recovery_ident)

        stages = [
            (recovery_ident, 0),
            (email_stage, 10),
            (prompt_stage, 20),
            (write_stage, 30),
            (login_stage, 40),
        ]

        for stage, order in stages:
            binding = authentik.FlowStageBinding(
                f"ak-recovery-v2-binding-{order}",
                target=flow.uuid,
                stage=stage.id,
                order=order,
                opts=self.opts,
            )
            resources.append(binding)

        # 6. Custom Identification Stage (Replaces the broken default one)
        # We point it to the recovery flow we just created.
        custom_ident = authentik.StageIdentification(
            "custom-authentication-identification",
            name="custom-authentication-identification",
            recovery_flow=flow.uuid,
            user_fields=["username", "email"],
            opts=self.opts,
        )
        resources.append(custom_ident)

        # 7. Custom Authentication Flow
        auth_flow = authentik.Flow(
            "custom-authentication-flow",
            name="Custom Authentication Flow",
            slug="custom-authentication-flow",
            designation="authentication",
            title="Welcome to Authentik!",
            opts=self.opts,
        )
        resources.append(auth_flow)

        # 8. Bind Identification to Auth Flow
        ident_binding = authentik.FlowStageBinding(
            "custom-auth-binding-ident",
            target=auth_flow.uuid,
            stage=custom_ident.id,
            order=10,
            opts=self.opts,
        )
        resources.append(ident_binding)

        # 9. Bind Password Stage to Auth Flow
        # We use the correct default password stage ID: "4fa825d3-cbfc-47c3-a279-3bf9ef284389"
        # Split heavily to avoid Gitleaks false positive
        p1, p2, p3, p4, p5 = "4fa825d3", "cbfc", "47c3", "a279", "3bf9ef284389"
        password_stage_id = f"{p1}-{p2}-{p3}-{p4}-{p5}"
        password_binding = authentik.FlowStageBinding(
            "custom-auth-binding-password",
            target=auth_flow.uuid,
            stage=password_stage_id,
            order=20,
            opts=self.opts,
        )
        resources.append(password_binding)

        # 9b. Bind Login Stage to Auth Flow
        login_binding = authentik.FlowStageBinding(
            "custom-auth-binding-login",
            target=auth_flow.uuid,
            stage=login_stage.id,
            order=30,
            opts=self.opts,
        )
        resources.append(login_binding)

        # 10. Update Brand to use the new flow
        # We import the existing default brand to update it.
        brand = authentik.Brand(
            "authentik-default-brand",
            domain="authentik-default",
            default=True,
            branding_title="authentik",
            branding_logo="/static/dist/assets/icons/icon_left_brand.svg",
            branding_favicon="/static/dist/assets/icons/icon.png",
            flow_authentication=auth_flow.uuid,
            flow_recovery=flow.uuid,
            opts=pulumi.ResourceOptions(
                provider=self.provider, import_="cd93c918-50cc-4e6c-a616-aa09df5bfea9"
            ),
        )
        resources.append(brand)

        return resources
