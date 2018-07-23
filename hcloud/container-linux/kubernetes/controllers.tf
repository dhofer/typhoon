# Controller Instance DNS records
resource "cloudflare_record" "controllers" {
  count = "${var.controller_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}"
  type = "A"
  ttl  = 300

  # IPv4 addresses of controllers
  value = "${element(hcloud_server.controllers.*.ipv4_address, count.index)}"
}

# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "cloudflare_record" "etcds" {
  count = "${var.controller_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  # DNS record (will be prepended to domain)
  name = "${var.cluster_name}-etcd${count.index}"
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  # TODO: wireguard ip
  value = "${element(hcloud_server.controllers.*.ipv4_address, count.index)}"
}

# Controller server instances
resource "hcloud_server" "controllers" {
  count = "${var.controller_count}"

  name       = "${var.cluster_name}-controller-${count.index}"
  datacenter = "${var.datacenter}"

  image       = "debian-9"
  server_type = "${var.controller_type}"
  rescue      = "linux64"

  user_data = "${element(data.ct_config.controller_ign.*.rendered, count.index)}"
  ssh_keys  = ["${var.ssh_ids}"]

  connection {
    type    = "ssh"
    timeout = "15m"
  }

  provisioner "file" {
    content = "${element(data.ct_config.controller_ign.*.rendered, count.index)}"
    destination = "/root/ignition.json"
  }

  provisioner "remote-exec" {
    inline = [
      "wget https://raw.github.com/coreos/init/master/bin/coreos-install",
      "chmod +x coreos-install",
      "./coreos-install -d /dev/sda -C ${var.channel} -i /root/ignition.json",
      "reboot",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

# Controller Container Linux Config
data "template_file" "controller_config" {
  count = "${var.controller_count}"

  template = "${file("${path.module}/cl/controller.yaml.tmpl")}"

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"

    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster  = "${join(",", data.template_file.etcds.*.rendered)}"
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"

    ssh_authorized_key    = "${var.ssh_authorized_key}"
  }
}

data "template_file" "etcds" {
  count    = "${var.controller_count}"
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars {
    index        = "${count.index}"
    cluster_name = "${var.cluster_name}"
    dns_zone     = "${var.dns_zone}"
  }
}

data "ct_config" "controller_ign" {
  count        = "${var.controller_count}"
  content      = "${element(data.template_file.controller_config.*.rendered, count.index)}"
  pretty_print = false

  snippets = ["${var.controller_clc_snippets}"]
}
