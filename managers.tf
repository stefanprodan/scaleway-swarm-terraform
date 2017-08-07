resource "scaleway_ip" "swarm_manager_ip" {
  count = 1
}

resource "scaleway_server" "swarm_manager" {
  count          = 1
  name           = "${terraform.workspace}-manager-${count.index + 1}"
  image          = "${data.scaleway_image.xenial.id}"
  type           = "${var.manager_instance_type}"
  bootscript     = "${data.scaleway_bootscript.rancher.id}"
  security_group = "${scaleway_security_group.swarm_managers.id}"
  public_ip      = "${element(scaleway_ip.swarm_manager_ip.*.ip, count.index)}"

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
    content     = "${data.template_file.docker_conf.rendered}"
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
      "docker swarm init --advertise-addr ${self.private_ip}",
      "curl -sSL git.io/scope -o /usr/local/bin/scope",
      "chmod a+x /usr/local/bin/scope",
      "scope launch --service-token=${var.weave_cloud_token}",
      "iptables -A INPUT -p tcp --dport 2375 -s ${var.docker_api_ip_allow} -j ACCEPT",
      "iptables -A INPUT -p tcp --dport 2375 -j DROP"
    ]
  }
}
