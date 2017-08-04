#!/usr/bin/env bash

DOCKER_VERSION=$1

# setup Docker repository
apt-get -qq update
apt-get -qq install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

# install Docker CE
apt-get -q update -y
apt-get -q install -y docker-ce=$DOCKER_VERSION

