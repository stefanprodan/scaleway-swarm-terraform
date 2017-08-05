resource "scaleway_ip" "swarm_worker_ip" {
  count = "${var.worker_instance_count}"
}

resource "scaleway_server" "swarm_worker" {
  count          = "${var.worker_instance_count}"
  name           = "${terraform.workspace}-worker-${count.index + 1}"
  image          = "${data.scaleway_image.xenial.id}"
  type           = "${var.worker_instance_type}"
  bootscript     = "${data.scaleway_bootscript.rancher.id}"
  security_group = "${scaleway_security_group.swarm_workers.id}"
  public_ip      = "${element(scaleway_ip.swarm_worker_ip.*.ip, count.index)}"

  connection {
    type = "ssh"
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/systemd/system/docker.service.d",
    ]
  }

  provisioner "file" {
    source      = "conf/docker.conf"
    destination = "/etc/systemd/system/docker.service.d/docker.conf"
  }

  provisioner "file" {
    source      = "scripts/install-docker-ce.sh"
    destination = "/tmp/install-docker-ce.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-docker-ce.sh",
      "/tmp/install-docker-ce.sh ${var.docker_version}",
      "docker swarm join --token ${data.external.swarm_tokens.result.worker} ${scaleway_server.swarm_manager.0.private_ip}:2377",
    ]
  }

  # drain worker on destroy
  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "docker node update --availability drain ${self.name}",
    ]

    on_failure = "continue"

    connection {
      type = "ssh"
      user = "root"
      host = "${scaleway_ip.swarm_manager_ip.0.ip}"
    }
  }

  # leave swarm on destroy
  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "docker swarm leave",
    ]

    on_failure = "continue"
  }

  # remove node on destroy
  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "docker node rm --force ${self.name}",
    ]

    on_failure = "continue"

    connection {
      type = "ssh"
      user = "root"
      host = "${scaleway_ip.swarm_manager_ip.0.ip}"
    }
  }
}

data "external" "swarm_tokens" {
  program = ["./scripts/fetch-tokens.sh"]

  query = {
    host = "${scaleway_ip.swarm_manager_ip.0.ip}"
  }

  depends_on = ["scaleway_server.swarm_manager"]
}
