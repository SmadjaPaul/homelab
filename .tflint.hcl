# TFLint configuration
# https://github.com/terraform-linters/tflint

config {
  # Enable all available rules by default
  module = true
}

# Disallow deprecated syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}

# Disallow legacy dot index syntax
rule "terraform_deprecated_index" {
  enabled = true
}

# Disallow variables, data sources, and locals that are not used
rule "terraform_unused_declarations" {
  enabled = true
}

# Disallow output declarations without description
rule "terraform_documented_outputs" {
  enabled = true
}

# Disallow variable declarations without description
rule "terraform_documented_variables" {
  enabled = true
}

# Disallow variable declarations without type
rule "terraform_typed_variables" {
  enabled = true
}

# Require naming conventions
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Require terraform version constraints
rule "terraform_required_version" {
  enabled = true
}

# Require provider version constraints
rule "terraform_required_providers" {
  enabled = true
}

# Ensure standard module structure
rule "terraform_standard_module_structure" {
  enabled = true
}
