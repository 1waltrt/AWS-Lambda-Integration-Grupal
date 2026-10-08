ENV ?= dev

.PHONY: build init plan apply destroy output fmt test

build:
	./scripts/build-lambdas.sh

init:
	@test -n "$(TF_STATE_BUCKET)" || (echo "Exporta TF_STATE_BUCKET (output de bootstrap)"; exit 1)
	cd envs/$(ENV) && terraform init -backend-config="bucket=$(TF_STATE_BUCKET)"

plan: build
	cd envs/$(ENV) && terraform plan -var-file=$(ENV).tfvars

apply: build
	cd envs/$(ENV) && terraform apply -var-file=$(ENV).tfvars

destroy:
	cd envs/$(ENV) && terraform destroy -var-file=$(ENV).tfvars

output:
	cd envs/$(ENV) && terraform output

fmt:
	terraform fmt -recursive

test:
	BUCKET=$$(terraform -chdir=envs/$(ENV) output -raw bucket_name) \
	./scripts/test-upload.sh "$$(terraform -chdir=envs/$(ENV) output -raw upload_url)"
