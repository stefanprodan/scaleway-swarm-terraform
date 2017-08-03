resource "scaleway_security_group" "swarm_managers" {
  name        = "swarm_managers"
  description = "Allow HTTP/S and SSH traffic"
}

resource "scaleway_security_group_rule" "ssh_accept" {
  security_group = "${scaleway_security_group.swarm_managers.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 22
}

resource "scaleway_security_group_rule" "http_accept" {
  security_group = "${scaleway_security_group.swarm_managers.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 80
}

resource "scaleway_security_group_rule" "https_accept" {
  security_group = "${scaleway_security_group.swarm_managers.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 443
}

resource "scaleway_security_group" "swarm_workers" {
  name        = "swarm_workers"
  description = "Allow SSH traffic"
}

resource "scaleway_security_group_rule" "ssh_accept_workers" {
  security_group = "${scaleway_security_group.swarm_workers.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "0.0.0.0/0"
  protocol  = "TCP"
  port      = 22
}
