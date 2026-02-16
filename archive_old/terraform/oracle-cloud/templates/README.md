# Templates (OCI Talos)

This directory previously contained Terraform templates for injecting Talos machine config via `user_data`. We now follow the [Omni-generated image approach](https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/): the Talos image is downloaded from Omni UI (pre-configured with credentials), imported to OCI, and used as `talos_image_id`. No user_data or secrets in Terraform.
