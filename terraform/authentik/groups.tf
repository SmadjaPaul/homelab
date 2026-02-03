# Groups (docs-site/docs/advanced/planning-conclusions.md §4.1, §4.5)
# admin: access to admin apps only
# family-validated: validated users; required (with optional app groups) for family apps

resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = false # set true only if this group should have full Authentik admin
}

resource "authentik_group" "family_validated" {
  name = "family-validated"
}

# Optional: per-app groups for granular assignment (e.g. family-app-nextcloud)
# resource "authentik_group" "family_app_nextcloud" {
#   name = "family-app-nextcloud"
# }
