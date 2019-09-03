# Worker Instance DNS records
resource "cloudflare_record" "workers" {
  count = var.worker_count

  # DNS zone where record should be created
  domain = var.dns_zone

  # DNS record (will be prepended to domain)
  name = var.cluster_name
  type = "A"
  ttl  = 300

  # IPv4 addresses of workers
  value = element(hcloud_server.workers.*.ipv4_address, count.index)
}

# Worker instances
resource "hcloud_server" "workers" {
  count = var.worker_count

  name       = "${var.cluster_name}-worker-${count.index}"
  datacenter = var.datacenter

  # hcloud doesn't support FCOS natively so we need to workaround with the rescue environment
  image       = "centos-7"
  server_type = var.worker_type
  rescue      = "linux64"

  user_data = element(data.ct_config.worker-ignitions.*.rendered, count.index)
  ssh_keys  = var.ssh_ids

  connection {
    host = self.ipv4_address
  }

  provisioner "file" {
    content = "${element(data.ct_config.worker-ignitions.*.rendered, count.index)}"
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

# Worker Ignition configs
data "ct_config" "worker-ignitions" {
  count    = var.worker_count
  content  = element(data.template_file.worker-configs.*.rendered, count.index)
  strict   = true
  snippets = var.worker_snippets
}

# Worker Fedora CoreOs configs
data "template_file" "worker-configs" {
  count = var.worker_count

  template = file("${path.module}/fcc/worker.yaml")

  vars = {
    kubeconfig             = indent(10, module.bootkube.kubeconfig-kubelet)
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    ssh_authorized_key     = var.ssh_authorized_key
    hostname               = "${var.cluster_name}-worker-${count.index}"
  }
}
