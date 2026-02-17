# Cluster Configuration
# ===================

schema ClusterConfig:
    name: str
    provider: str
    domain: str
    region?: str

ociCluster = ClusterConfig {
    name = "oci"
    provider = "oracle"
    domain = "smadja.dev"
    region = "eu-paris-1"
}

homeCluster = ClusterConfig {
    name = "home"
    provider = "talos"
    domain = "home.smadja.dev"
}
