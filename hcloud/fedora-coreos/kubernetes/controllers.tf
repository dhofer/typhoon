# Controller Instance DNS records
resource "cloudflare_record" "controllers" {
  count = var.controller_count

  # DNS zone where record should be created
  domain = var.dns_zone

  # DNS record (will be prepended to domain)
  name = var.cluster_name
  type = "A"
  ttl  = 300

  # IPv4 addresses of controllers
  value = element(hcloud_server.controllers.*.ipv4_address, count.index)
}

# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "cloudflare_record" "etcds" {
  count = var.controller_count

  # DNS zone where record should be created
  domain = var.dns_zone

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}-etcd${count.index}"
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  value = element(hcloud_server.controllers.*.ipv4_address, count.index)
}

# Controller server instances
resource "hcloud_server" "controllers" {
  count = var.controller_count

  name       = "${var.cluster_name}-controller-${count.index}"
  datacenter = var.datacenter

  # hcloud doesn't support FCOS natively so we need to workaround with the rescue environment
  image       = "centos-7"
  server_type = var.controller_type
  rescue      = "linux64"

  user_data = element(data.ct_config.controller-ignitions.*.rendered, count.index)
  ssh_keys  = var.ssh_ids

  connection {
    host = self.ipv4_address
  }

  provisioner "file" {
    content = "${element(data.ct_config.controller-ignitions.*.rendered, count.index)}"
    destination = "/tmp/ignition.ign"
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get install -y dc",
      "wget https://raw.githubusercontent.com/coreos/coreos-installer/master/coreos-installer",
      "chmod +x coreos-installer",
      "./coreos-installer -d sda -i /tmp/ignition.ign -b ${var.fcos_image}",
      "shutdown -r +1 && echo 0",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 65"
  }

  provisioner "remote-exec" {
    connection {
      host = self.ipv4_address
      user = "core"
    }
    # Second reboot because of https://github.com/coreos/fedora-coreos-tracker/issues/233
    inline = [
      "sudo shutdown -r +1 && echo 0",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 65"
  }
}

# Controller Ignition configs
data "ct_config" "controller-ignitions" {
  count    = var.controller_count
  content  = element(data.template_file.controller-configs.*.rendered, count.index)
  strict   = true
  snippets = var.controller_snippets
}

# Controller Fedora Core OS configs
data "template_file" "controller-configs" {
  count = var.controller_count

  template = file("${path.module}/fcc/controller.yaml")

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"
    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster   = join(",", data.template_file.etcds.*.rendered)
    kubeconfig             = indent(10, module.bootkube.kubeconfig-kubelet)
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
    hostname               = "${var.cluster_name}-controller-${count.index}"
  }
}

data "template_file" "etcds" {
  count    = var.controller_count
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars = {
    index        = count.index
    cluster_name = var.cluster_name
    dns_zone     = var.dns_zone
  }
}

