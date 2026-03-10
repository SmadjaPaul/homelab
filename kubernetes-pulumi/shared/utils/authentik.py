import pulumi
import pulumi_kubernetes as k8s
import pulumi_authentik as authentik


def create_authentik_provider(
    domain: str, k8s_provider: k8s.Provider
) -> authentik.Provider:
    """
    Creates a Pulumi Authentik provider pointing to the internal cluster service.
    This allows configuring Authentik resources (users, groups, apps) via Pulumi.
    """

    # We use the bootstrap token from the secret managed by the registry
    # or passed via environment/doppler.
    # Use the public domain for the provider endpoint
    base_url = domain.apply(lambda d: f"https://auth.{d}")

    # Get the bootstrap token from the secret in the authentik namespace
    # We use a SecretReference here
    bootstrap_secret = k8s.core.v1.Secret.get(
        "authentik-vars-ref",
        id=pulumi.Output.concat("authentik/", "authentik-vars"),
        opts=pulumi.ResourceOptions(provider=k8s_provider),
    )

    import base64

    token = bootstrap_secret.data["AUTHENTIK_BOOTSTRAP_TOKEN"].apply(
        lambda b: base64.b64decode(b).decode()
    )

    return authentik.Provider(
        "authentik-provider",
        url=base_url,
        token=token,
        # Set insecure to True if using self-signed certs internally,
        # but we use cert-manager with Let's Encrypt usually.
        insecure=True,
    )
