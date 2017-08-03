SHELL:=/bin/bash

init:
	@brew update
	@brew install terraform
	@terraform -v
	@brew install jq
	@jq --version
	@terraform init

reset:
	@terraform destroy -force
	@terraform apply
