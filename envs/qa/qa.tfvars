environment                 = "qa"
vpc_cidr                    = "10.1.0.0/16"
nat_gateway_count           = 1
log_retention_days          = 14
lambda_reserved_concurrency = -1 # sin límite
alarm_email                 = "CAMBIAR@correo.com" # correo del equipo
force_destroy               = true
