# Secure Auth0 User Management

This project uses a hybrid GitOps approach for Auth0 users to ensure no passwords are committed to the repository.

## How it works

1. **User Metadata (Git)**: Users, their names, nicknames, and roles are defined in `terraform/auth0/terraform.tfvars`. The `password` field is left empty or as a placeholder.
2. **Passwords (Doppler)**: All passwords are stored in a single Doppler secret named `AUTH0_PASSWORDS`. This secret is a JSON object where keys are the usernames defined in Terraform and values are their respective passwords.
   ```json
   {
     "paul": "SecurePassword123!"
   }
   ```
3. **Merging (Terraform)**: The Auth0 `main.tf` decodes the JSON from Doppler and merges the passwords into the user definitions before creating them in Auth0.

## Adding a New User

1. **Add to Doppler**:
   ```bash
   # Get current passwords
   passwords=$(doppler secrets get AUTH0_PASSWORDS --plain)
   # Update JSON and set back
   doppler secrets set AUTH0_PASSWORDS='{"paul": "...", "newuser": "SecurePass123"}'
   ```
2. **Add to Terraform**:
   Update `terraform/auth0/terraform.tfvars`:
   ```hcl
   users = {
     paul = { ... }
     newuser = {
       email    = "newuser@smadja.dev"
       name     = "New User"
       nickname = "newuser"
       password = ""
       roles    = ["family"]
     }
   }
   ```
3. **Deploy**:
   Commit and push. The CI will pick up the change and create the user with the password from Doppler.
