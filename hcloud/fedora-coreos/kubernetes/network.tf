resource "hcloud_network" "network" {
  name = "network"
  ip_range = "10.1.0.0/16"
}

resource "hcloud_network_subnet" "subnet" {
  type = "server"
  network_id = hcloud_network.network.id
  ip_range = "10.1.0.0/24"
  network_zone = "eu-central"
}

resource "hcloud_server_network" "controllers" {
  count = var.controller_count
  network_id = hcloud_network.network.id
  server_id = element(hcloud_server.controllers.*.id, count.index)
}

resource "hcloud_server_network" "workers" {
  network_id = hcloud_network.network.id
  server_id = element(hcloud_server.workers.*.id, count.index)
  count = length(hcloud_server.workers)
}
