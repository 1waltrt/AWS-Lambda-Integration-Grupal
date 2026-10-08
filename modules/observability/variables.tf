variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "dlq_name" {
  description = "Nombre de la DLQ (sale de storage)"
  type        = string
}

variable "alarm_email" {
  description = "Correo que recibe la alerta de la DLQ (debe confirmar la suscripción)"
  type        = string
}
