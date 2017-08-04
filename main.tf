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
