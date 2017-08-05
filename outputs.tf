output "swarm_manager_public_ip" {
  value = "${scaleway_ip.swarm_manager_ip.0.ip}"
}

output "swarm_manager_private_ip" {
  value = "${scaleway_server.swarm_manager.0.private_ip}"
}

output "swarm_manager_token" {
  value = "${data.external.swarm_tokens.result.manager}"
}

output "swarm_workers_public_ip" {
  value = "${concat(scaleway_server.swarm_worker.*.name, scaleway_server.swarm_worker.*.public_ip)}"
}

output "swarm_workers_private_ip" {
  value = "${concat(scaleway_server.swarm_worker.*.name, scaleway_server.swarm_worker.*.private_ip)}"
}

output "swarm_worker_token" {
  value = "${data.external.swarm_tokens.result.worker}"
}

output "workspace" {
  value = "${terraform.workspace}"
}
