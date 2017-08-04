# scaleway-swarm-terraform

Setup a Docker Swarm Cluster on Scaleway with Terraform

### Initial setup

Clone the repository and install the dependencies:

```bash
$ git clone https://github.com/stefanprodan/scaleway-swarm-terraform.git
$ cd scaleway-swarm-terraform

# requires brew
$ make init
```

Running `make init` will install Terraform and jq using `brew` 
and will pull the required Terraform modules. 
If you are on linux, after installing Terraform and jq packages, run `terraform init`.

Before running the project you'll need to create an access token for Terraform to connect to Scaleway API. 
Navigate to Scaleway dashboard and click on Credentials under your name dropdown. 
You'll need to add your public SSH key and create a new token. 

Using this token and your access key, create two environment variables:

```bash
$ export SCALEWAY_ORGANIZATION="<ACCESS-KEY>"
$ export SCALEWAY_TOKEN="<ACCESS-TOKEN>" 
```

### Usage

Create a Docker Swarm Cluster with one manager and two workers:

```bash
terraform plan
terraform apply 
```

This will do the following:

* reserves public IPs for each node
* creates a security group for the manager node allowing SSH and HTTP/S inbound traffic
* creates a security group for the worker nodes allowing SSH inbound traffic
* provisions three VC1S servers with Ubuntu 16.04 LTS and Rancher boot script
* starts the manager node and installs Docker CE using the local SSH agent
* customizes the Docker daemon systemd config by enabling the experimental features and the metrics endpoint
* initializes the manager node as Docker Swarm manager and extracts the join tokens
* starts the worker nodes in parallel and setups Docker CE the same as on the manager node
* joins the worker nodes in the cluster using the manager node private IP

Customizing the cluster specs via terraform variables:

```bash
terraform apply \
-var docker_version=17.06.0~ce-0~ubuntu \
-var region=ams1 \
-var manager_instance_type=VC1S \
-var worker_instance_type=VC1S \
-var worker_instance_count=2
```

You can scale up or down the Docker Swarm Cluster by modifying the `worker_instance_count`, 
the manager will reschedule the services on the remaining nodes if you chose to scale down.

After running the Terraform plan you'll see several output variables like the Swarm tokes, 
the private and public IPs of each node and the current workspace. 
You can use the manager public IP variable to connect via SSH and lunch a service within the Swarm.

```bash
$ ssh root@$(terraform output swarm_manager_public_ip)

root@swarm-manager-1:~# docker service create -d --name nginx -p 80:80 --replicas 2 nginx

$ curl $(terraform output swarm_manager_public_ip)
```
