provider "scaleway" {
  region = "ams1"
}

data "scaleway_bootscript" "latest" {
  architecture = "x86_64"
  name_filter  = "latest"
}

data "scaleway_image" "xenial" {
  architecture = "x86_64"
  name         = "Ubuntu Xenial"
}

resource "scaleway_server" "swarm_manager" {
  count          = 1
  name           = "swarm_manager-${count.index + 1}"
  image          = "${data.scaleway_image.xenial.id}"
  type           = "VC1S"
  bootscript     = "${data.scaleway_bootscript.latest.id}"
  security_group = "${scaleway_security_group.swarm_default.id}"
}

resource "scaleway_ip" "swarm_manager_ip" {
  server = "${scaleway_server.swarm_manager.id}"
}

resource "scaleway_security_group" "swarm_default" {
  name        = "swarm_default"
  description = "Allow SSH traffic"
}

resource "scaleway_security_group_rule" "ssh_accept" {
  security_group = "${scaleway_security_group.swarm_default.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 22
}

resource "scaleway_security_group_rule" "http_accept" {
  security_group = "${scaleway_security_group.swarm_default.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 80
}

resource "scaleway_security_group_rule" "https_accept" {
  security_group = "${scaleway_security_group.swarm_default.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 443
}
