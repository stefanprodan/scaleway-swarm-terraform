provider "scaleway" {
  region = "ams1"
}

// Using Racher since Scaleway Docker bootstrap is missing IPVS_NFCT and IPVS_RR
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
  security_group = "${scaleway_security_group.swarm_managers.id}"
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

data "external" "swarm_tokens" {
  program = ["./fetch-tokens.sh"]
  query = {
    host = "${scaleway_ip.swarm_manager_ip.0.ip}"
  }
  depends_on = ["scaleway_server.swarm_manager"]
}

resource "scaleway_ip" "swarm_worker_ip" {
  count = 2
}

resource "scaleway_server" "swarm_worker" {
  count          = 2
  name           = "swarm_worker-${count.index + 1}"
  image          = "${data.scaleway_image.xenial.id}"
  type           = "VC1S"
  bootscript     = "${data.scaleway_bootscript.rancher.id}"
  security_group = "${scaleway_security_group.swarm_workers.id}"
  public_ip      = "${element(scaleway_ip.swarm_worker_ip.*.ip, count.index)}"

  connection {
    type = "ssh"
    user = "root"
  }

  provisioner "remote-exec" {
    script = "install-docker-ce.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "docker swarm join --token ${data.external.swarm_tokens.result.worker} ${scaleway_server.swarm_manager.0.private_ip}:2377",
    ]
  }
}
