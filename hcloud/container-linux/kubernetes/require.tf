# Terraform version and plugin versions

terraform {
  required_version = ">= 0.11.0"
}

provider "hcloud" {
  version = "~> 1.2.0"
}

provider "cloudflare" {
  version = "~> 1.0.0"
}

provider "local" {
  version = "~> 1.0"
}

provider "null" {
  version = "~> 1.0"
}

provider "template" {
  version = "~> 1.0"
}

provider "tls" {
  version = "~> 1.0"
}
