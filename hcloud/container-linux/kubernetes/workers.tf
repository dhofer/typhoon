# Worker DNS records
resource "cloudflare_record" "workers" {
  count = "${var.worker_count}"

  # DNS zone where record should be created
  domain = "${var.dns_zone}"

  name  = "${var.cluster_name}-workers"
  type  = "A"
  ttl   = 300
  value = "${element(hcloud_server.workers.*.ipv4_address, count.index)}"
}

# Worker server instances
resource "hcloud_server" "workers" {
  count = "${var.worker_count}"

  name       = "${var.cluster_name}-worker-${count.index}"
  datacenter = "${var.datacenter}"

  image       = "debian-9"
  server_type = "${var.worker_type}"
  rescue      = "linux64"

  user_data = "${data.ct_config.worker_ign.rendered}"
  ssh_keys  = ["${var.ssh_ids}"]

  connection {
    type    = "ssh"
    timeout = "15m"
  }

  provisioner "file" {
    content = "${data.ct_config.worker_ign.rendered}"
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

# Worker Container Linux Config
data "template_file" "worker_config" {
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars = {
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
    ssh_authorized_key    = "${var.ssh_authorized_key}"
  }
}

data "ct_config" "worker_ign" {
  content      = "${data.template_file.worker_config.rendered}"
  pretty_print = false
  snippets     = ["${var.worker_clc_snippets}"]
}
