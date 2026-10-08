variable "project" {
  type    = string
  default = "image-processor"
}

variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "nat_gateway_count" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "lambda_reserved_concurrency" {
  description = "-1 = sin límite"
  type        = number
  default     = -1
}

variable "alarm_email" {
  type = string
}

variable "max_upload_bytes" {
  description = "Máximo real ~4.5 MB por el límite de 6 MB de payload de Lambda (ver README)"
  type        = number
  default     = 4500000
}

variable "force_destroy" {
  description = "true para poder destruir el bucket con objetos (evidencia del destroy)"
  type        = bool
  default     = true
}
