variable "project" {
  description = "Nombre del proyecto (prefijo de todos los recursos)"
  type        = string
}

variable "environment" {
  description = "dev  |  qa  |  prod"
  type        = string
}

variable "region" {
  description = "Región AWS (para los nombres de servicio de los VPC endpoints)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC. Las subnets se derivan con cidrsubnet(/24): públicas .1 y .2, privadas .11 y .12"
  type        = string
}

variable "nat_gateway_count" {
  description = "1 = un NAT compartido por ambas subnets privadas, 2 = un NAT por AZ (alta disponibilidad)"
  type        = number

  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count debe ser 1 o 2."
  }
}

variable "bucket_arn" {
  description = "ARN del bucket de imágenes (limita la policy del S3 Gateway Endpoint). Sale del módulo storage."
  type        = string
}
