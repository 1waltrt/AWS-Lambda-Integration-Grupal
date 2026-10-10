environment                 = "prod"
vpc_cidr                    = "10.2.0.0/16"
nat_gateway_count           = 2
log_retention_days          = 14
lambda_reserved_concurrency = -1 # opcional: fijar un número si la cuenta lo permite
alarm_email                 = walterarhuischigne@gmail.com
force_destroy               = true # en un PROD real poner false
