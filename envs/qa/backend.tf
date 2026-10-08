# El bucket se pasa al hacer init (no se hardcodea):
#   terraform init -backend-config="bucket=$TF_STATE_BUCKET"
# o simplemente: make init ENV=dev
terraform {
  backend "s3" {
    key          = "qa/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
