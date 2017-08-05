# scaleway-swarm-terraform

Automating Docker Swarm cluster operations with Terraform Scaleway provider.

### Initial setup

Clone the repository and install the dependencies:

```bash
$ git clone https://github.com/stefanprodan/scaleway-swarm-terraform.git
$ cd scaleway-swarm-terraform

# requires brew
$ make init
```

Running `make init` will install Terraform and jq using Homebrew and will pull the required Terraform modules. 
If you are on linux, after installing Terraform and jq packages, run `terraform init`. 
Note that you'll need Terraform v0.10 or newer to run this project.

Before running the project you'll have to create an access token for Terraform to connect to the Scaleway API. 
Using the token and your access key, create two environment variables:

```bash
$ export SCALEWAY_ORGANIZATION="<ACCESS-KEY>"
$ export SCALEWAY_TOKEN="<ACCESS-TOKEN>" 
```

### Usage

Create a Docker Swarm Cluster with one manager and two workers:

```bash
# create a workspace
terraform workspace new dev

# generate plan
terraform plan

# run the plan
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

The naming convention for a swarm node is in `<WORKSPACE>-<ROLE>-<INDEX>` format, 
running the project on workspace dev will create 3 nodes: dev-manager-1, dev-worker-1, dev-worker-2. 
If you don't create a workspace then you'll be running on the default one and your nods prefix will be `default`. 
You can have multiple workspaces, each with it's own state, so you can run in parallel different Docker Swarm clusters.

Customizing the cluster specs via terraform variables:

```bash
terraform apply \
-var docker_version=17.06.0~ce-0~ubuntu \
-var region=ams1 \
-var manager_instance_type=VC1S \
-var worker_instance_type=VC1S \
-var worker_instance_count=2
```

You can scale up or down the Docker Swarm Cluster by modifying the `worker_instance_count`. 
On scale up, all new nodes will join the current cluster. 
When you scale down the workers, Terraform will first drain the node 
and remove it from the swarm before destroying the resources.

After running the Terraform plan you'll see several output variables like the Swarm tokes, 
the private and public IPs of each node and the current workspace. 
You can use the manager public IP variable to connect via SSH and lunch a service within the Swarm.

```bash
$ ssh root@$(terraform output swarm_manager_public_ip)

root@dev-manager-1:~# docker service create \
    --name nginx -dp 80:80 \
    --replicas 2 \
    --constraint 'node.role == worker' nginx

$ curl $(terraform output swarm_manager_public_ip)
```

You could also expose the Docker engine remote API and metrics endpoint on the public IP by running:

```bash
terraform apply -var docker_api_ip="0.0.0.0"
```

If you chose to do so, you should allow access to the API only from your IP. 
You'll have to add a security group rule for ports 2375 and 9323 to the managers and workers groups.

Test your settings by calling the API and metrics endpoint:

```bash
$ curl $(terraform output swarm_manager_public_ip):2375/containers/json

$ curl $(terraform output swarm_manager_public_ip):9323/metrics
```

Tear down the whole infrastructure with:

 ```bash
terraform destroy -force
```

Please see my [blog post](https://stefanprodan.com/2017/terraform-docker-swarm-cluster-scaleway/) for more information.
