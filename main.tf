provider "scaleway" {
  region = "ams1"
}

// Racher is required since Scaleway Docker bootstrap is missing IPVS_NFCT and IPVS_RR
// https://github.com/moby/moby/issues/28168
data "scaleway_bootscript" "rancher" {
  architecture = "x86_64"
  name_filter  = "rancher"
}

data "scaleway_image" "xenial" {
  architecture = "x86_64"
  name         = "Ubuntu Xenial"
}

resource "scaleway_ip" "swarm_manager_ip" {}

resource "scaleway_server" "swarm_manager" {
  count          = 1
  name           = "swarm_manager-${count.index + 1}"
  image          = "${data.scaleway_image.xenial.id}"
  type           = "VC1S"
  bootscript     = "${data.scaleway_bootscript.rancher.id}"
  security_group = "${scaleway_security_group.swarm_default.id}"
  public_ip      = "${scaleway_ip.swarm_manager_ip.ip}"

  connection {
    type = "ssh"
    user = "root"
  }

  provisioner "remote-exec" {
    script = "install-docker-ce.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "docker swarm init --advertise-addr ${self.private_ip}",
    ]
  }
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
