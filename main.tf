provider "scaleway" {
  region = "${var.region}"
}

// Using Racher since Scaleway Docker bootstrap is missing IPVS_NFCT and IPVS_RR
// https://github.com/moby/moby/issues/28168
data "scaleway_bootscript" "rancher" {
  architecture = "x86_64"
  //name_filter  = "docker"
  name = "x86_64 mainline 4.9.48 rev1"
}

data "scaleway_image" "xenial" {
  architecture = "x86_64"
  name         = "Ubuntu Xenial"
}

data "template_file" "docker_conf" {
  template = "${file("conf/docker.tpl")}"

  vars {
    ip = "${var.docker_api_ip}"
  }
}
