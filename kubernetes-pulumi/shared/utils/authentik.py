import pulumi
import pulumi_kubernetes as k8s
import pulumi_authentik as authentik


def create_authentik_provider(
    domain: str,
    k8s_provider: k8s.Provider,
    bootstrap_token: pulumi.Input[str] = None,
) -> authentik.Provider:
    """
    Creates a Pulumi Authentik provider pointing to the internal cluster service.
    This allows configuring Authentik resources (users, groups, apps) via Pulumi.

    Prefer passing bootstrap_token from Doppler secrets directly (more reliable than
    reading from a K8s Secret that may not be synced by ESO yet).
    """

    base_url = "http://localhost:9000"

    if bootstrap_token is None:
        # Fallback: read from the K8s secret (requires ESO to have synced it)
        import base64

        bootstrap_secret = k8s.core.v1.Secret.get(
            "authentik-vars-ref",
            id=pulumi.Output.concat("authentik/", "authentik-vars"),
            opts=pulumi.ResourceOptions(provider=k8s_provider),
        )
        bootstrap_token = bootstrap_secret.data.apply(
            lambda d: base64.b64decode(d["AUTHENTIK_BOOTSTRAP_TOKEN"]).decode()
        )

    return authentik.Provider(
        "authentik-provider",
        url=base_url,
        token=bootstrap_token,
        insecure=True,
    )
