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
and remove it from the swarm before destroying the resource.

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

```tf
resource "scaleway_security_group_rule" "docker_api_accept" {
  security_group = "${scaleway_security_group.swarm_managers.id}"

  action    = "accept"
  direction = "inbound"
  ip_range  = "<YOUR-IP-RANGE>"
  protocol  = "TCP"
  port      = 2375
}
```

Test your settings by calling the API and metrics endpoint from your computer:

```bash
$ curl $(terraform output swarm_manager_public_ip):2375/containers/json

$ curl $(terraform output swarm_manager_public_ip):9323/metrics
```

### Code walkthrough 

The first step is to define the Scaleway provider, base image and boot script. You have to use 
Racher boost script since Scaleway's custom Xenial kernel is missing IPVS_NFCT and IPVS_RR.

```tf
provider "scaleway" {
  region = "${var.region}"
}

data "scaleway_bootscript" "rancher" {
  architecture = "x86_64"
  name_filter  = "rancher"
}

data "scaleway_image" "xenial" {
  architecture = "x86_64"
  name         = "Ubuntu Xenial"
}
```

As you can see, the Scaleway region is loaded from the region variables. This allows you to change the region 
when running Terraform apply. Besides the region there are more variables define, 
all located in the `variables.tf` file.

```tf
variable "region" {
  default = "ams1"
}

variable "manager_instance_type" {
  default = "VC1S"
}

variable "worker_instance_type" {
  default = "VC1S"
}

variable "worker_instance_count" {
  default = 2
}

variable "docker_version" {
  default = "17.06.0~ce-0~ubuntu"
}

variable "docker_api_ip" {
  default = "127.0.0.1"
}
```

In order to create the Swarm manager, first you need to reserve a public IP for it. Terraform provisioners 
will use this IP to run the commands on the manager node via SSH.

```tf
resource "scaleway_ip" "swarm_manager_ip" {
  count = 1
}
``` 

Having the public IP resource, the Scalewaly image and boostscript you can define a server that will act as the
Swarm manager.

```tf
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
    ]
  }
}
```

After Terraform creates the server based on the configuration block, it will connect via SSH to execute a series 
of commands. First it will create the directory for Docker engine systemd conf file, then it will render the conf 
file using the `docker_conf` template and it will copy this file on the manager server. 

```bash
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// \
  -H tcp://${ip}:2375 \
  --storage-driver=overlay2 \
  --dns 8.8.4.4 --dns 8.8.8.8 \
  --log-driver json-file \
  --log-opt max-size=50m --log-opt max-file=10 \
  --experimental=true \
  --metrics-addr ${ip}:9323
```

I'm using a template so at runtime you can change the IP variable in order to expose the Docker remote API and 
metrics endpoint on the internet. By default the IP value is 127.0.0.1 so it doesn't present a security risk. 
The template resource is defined as:

```tf
data "template_file" "docker_conf" {
  template = "${file("conf/docker.tpl")}"

  vars {
    ip = "${var.docker_api_ip}"
  }
}
```

Next the Docker CE script is copied on the server and executed. The script receives the Docker CE 
version to install, this way you'll not end up with different Docker versions if you decide to 
scale up the cluster at a later time. After Docker is installed this node is initialize as the Swarm manager.

Before you can start creating the Swarm worker nodes you'll need a way to store the join token generated by the 
manager. Storing data not exposed by the Terraform providers can be done using an external data source. The 
external data source protocol receives a JSON object and expects another JSON as output. 

```bash
#!/usr/bin/env bash
set -e

eval "$(jq -r '@sh "HOST=\(.host)"')"

MANAGER=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$HOST docker swarm join-token manager -q)

WORKER=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@$HOST docker swarm join-token worker -q)

jq -n --arg manager "$MANAGER" --arg worker "$WORKER" \
    '{"manager":$manager,"worker":$worker}'
```

The above script extracts the host argument from the input JSON, connects to the manager node and returns 
the two tokens as a JSON object. Using this script you can define an external data source like this:

```tf
data "external" "swarm_tokens" {
  program = ["./scripts/fetch-tokens.sh"]

  query = {
    host = "${scaleway_ip.swarm_manager_ip.0.ip}"
  }

  depends_on = ["scaleway_server.swarm_manager"]
}
```

You need to mark this data source as dependent on the existence of the manager node or Terraform will execute it 
right after the manager's public IP has been reserved and before the actual server has been created resulting in 
a SSH connection error.

Having the join token you can proceed with the Swarm workers provision. The worker server configuration is 
similar to the manager with some additions. After installing Docker CE, using the worker token and the manager's 
private IP these servers will join the Swarm as worker nodes.

```tf
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
      "docker swarm join --token ${data.external.swarm_tokens.result.worker} ${scaleway_server.swarm_manager.0.private_ip}:2377",
    ]
  }

  # drain and remove the node on destroy
}
```

If the number of worker nodes is decreased, you need to make sure they also get removed from the Swarm. 
Terraform let's you react to destroy actions, so you can create a provisioner that will connect to the manager node 
and issue a remove command. You can also drain the node and make him leave the cluster before it gets destroyed. 

```tf
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

  provisioner "remote-exec" {
    when = "destroy"

    inline = [
      "docker swarm leave",
    ]

    on_failure = "continue"
  }

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
```

