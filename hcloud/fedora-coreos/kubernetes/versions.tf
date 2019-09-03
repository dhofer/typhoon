# Terraform version and plugin versions

terraform {
  required_version = "~> 0.12.0"
  required_providers {
    hcloud       = "~> 1.12.0"
    cloudflare   = "~> 1.17.0"
    ct           = "~> 0.4"
    template     = "~> 2.1"
    null         = "~> 2.1"
  }
}
