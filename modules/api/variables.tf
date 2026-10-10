variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "upload_lambda_name" {
  description = "Sale de compute"
  type        = string
}

variable "upload_lambda_invoke_arn" {
  description = "Sale de compute"
  type        = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "throttling_rate_limit" {
  description = "Requests por segundo"
  type        = number
  default     = 10000

  validation {
    condition     = var.throttling_rate_limit > 0 && var.throttling_rate_limit <= 10000
    error_message = "throttling_rate_limit debe estar entre 1 y 10000."
  }
}

variable "throttling_burst_limit" {
  type    = number
  default = 5000
}

variable "cors_allowed_origins" {
  type    = list(string)
  default = ["*"]
}
