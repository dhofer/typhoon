variable "cluster_name" {
  type        = string
  description = "Unique cluster name (prepended to dns_zone)"
}

# Hetzner Cloud

variable "datacenter" {
  type        = string
  description = "Hetzner Cloud datacenter (e.g. fsn1-dc8, nbg1-dc3, hel1-dc2)"
}

# Cloudflare

variable "dns_zone" {
  type        = string
  description = "Cloudflare domain (i.e. DNS zone) (e.g. example.com)"
}

# instances

variable "controller_count" {
  type        = string
  default     = "1"
  description = "Number of controllers (i.e. masters)"
}

variable "worker_count" {
  type        = string
  default     = "1"
  description = "Number of workers"
}

variable "controller_type" {
  type        = string
  default     = "cx11"
  description = "Server type for controllers (e.g. cx11, cx21, cx31-ceph)"
}

variable "worker_type" {
  type        = string
  default     = "cx11"
  description = "Server type for workers (e.g. cx11, cx21, cx31-ceph)"
}

variable "fcos_image" {
  type        = string
  default     = "https://builds.coreos.fedoraproject.org/prod/streams/testing/builds/30.20190801.0/x86_64/fedora-coreos-30.20190801.0-metal.raw.xz"
  description = "Fedora Core OS image"
}

variable "controller_snippets" {
  type        = list(string)
  description = "Controller FCOS Config snippets"
  default     = []
}

variable "worker_snippets" {
  type        = list(string)
  description = "Worker FCOS Config snippets"
  default     = []
}

# configuration

variable "ssh_ids" {
  type        = list(string)
  description = "Hetzner Cloud SSH public key IDs."
}

variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key for user 'core'"
}

variable "asset_dir" {
  description = "Path to a directory where generated assets should be placed (contains secrets)"
  type        = string
}

variable "networking" {
  description = "Choice of networking provider (flannel or calico)"
  type        = string
  default     = "flannel"
}

variable "pod_cidr" {
  description = "CIDR IPv4 range to assign Kubernetes pods"
  type        = string
  default     = "10.2.0.0/16"
}

variable "service_cidr" {
  description = <<EOD
CIDR IPv4 range to assign Kubernetes services.
The 1st IP will be reserved for kube_apiserver, the 10th IP will be reserved for coredns.
EOD

  type    = string
  default = "10.3.0.0/16"
}

variable "cluster_domain_suffix" {
  description = "Queries for domains with the suffix will be answered by coredns. Default is cluster.local (e.g. foo.default.svc.cluster.local) "
  type        = string
  default     = "cluster.local"
}

variable "enable_reporting" {
  type = string
  description = "Enable usage or analytics reporting to upstreams (Calico)"
  default = "false"
}

variable "enable_aggregation" {
  description = "Enable the Kubernetes Aggregation Layer (defaults to false)"
  type        = string
  default     = "false"
}

