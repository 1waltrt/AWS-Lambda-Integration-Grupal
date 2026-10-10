terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "storage" {
  source = "../../modules/storage"

  project       = var.project
  environment   = var.environment
  force_destroy = var.force_destroy
}

module "network" {
  source = "../../modules/network"

  project           = var.project
  environment       = var.environment
  region            = var.region
  vpc_cidr          = var.vpc_cidr
  nat_gateway_count = var.nat_gateway_count
  bucket_arn        = module.storage.bucket_arn
}

module "compute" {
  source = "../../modules/compute"

  project            = var.project
  environment        = var.environment
  bucket_name        = module.storage.bucket_name
  bucket_arn         = module.storage.bucket_arn
  queue_arn          = module.storage.queue_arn
  private_subnet_ids = module.network.private_subnet_ids
  sg_upload_id       = module.network.sg_upload_id
  sg_crop_id         = module.network.sg_crop_id

  log_retention_days   = var.log_retention_days
  reserved_concurrency = var.lambda_reserved_concurrency
  max_upload_bytes     = var.max_upload_bytes

  upload_source_dir = "${path.root}/../../src/upload-lambda"
  crop_source_dir   = "${path.root}/../../src/crop-lambda"
  build_dir         = "${path.root}/.build"
}

module "api" {
  source = "../../modules/api"

  project                  = var.project
  environment              = var.environment
  upload_lambda_name       = module.compute.upload_lambda_name
  upload_lambda_invoke_arn = module.compute.upload_lambda_invoke_arn
  log_retention_days       = var.log_retention_days
}

module "observability" {
  source = "../../modules/observability"

  project     = var.project
  environment = var.environment
  dlq_name    = module.storage.dlq_name
  alarm_email = var.alarm_email
}
