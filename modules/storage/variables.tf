variable "project" {
  description = "Nombre del proyecto"
  type        = string
}

variable "environment" {
  description = "dev | qa | prod"
  type        = string
}

variable "force_destroy" {
  description = "Permite que terraform destroy borre el bucket aunque tenga objetos/versiones (necesario para la evidencia del destroy)"
  type        = bool
  default     = true
}
