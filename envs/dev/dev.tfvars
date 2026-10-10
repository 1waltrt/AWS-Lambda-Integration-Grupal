environment                 = "dev"
vpc_cidr                    = "10.0.0.0/16"
nat_gateway_count           = 1
log_retention_days          = 7
lambda_reserved_concurrency = -1 # sin límite
alarm_email                 = "walterarhuischigne@gmail.com"
force_destroy               = true
