variable "project" {
  type = string
}

variable "environment" {
  type = string
}

# ── Vienen de storage ────────────────────────────────────────────────────────
variable "bucket_name" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "queue_arn" {
  type = string
}

# ── Vienen de network ────────────────────────────────────────────────────────
variable "private_subnet_ids" {
  type = list(string)
}

variable "sg_upload_id" {
  type = string
}

variable "sg_crop_id" {
  type = string
}

# ── Propios del módulo ───────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "Retención de los log groups de las Lambdas"
  type        = number
  default     = 14
}

variable "reserved_concurrency" {
  description = "-1 = sin límite (por defecto). Cuentas nuevas no permiten reservar concurrencia."
  type        = number
  default     = -1
}

variable "max_upload_bytes" {
  description = "Tamaño máximo por imagen. OJO: la invocación síncrona de Lambda admite 6 MB de payload; con base64 el máximo real ronda 4.5 MB."
  type        = number
  default     = 4500000
}

variable "upload_source_dir" {
  description = "Carpeta de src/upload-lambda (con node_modules ya instalado)"
  type        = string
}

variable "crop_source_dir" {
  description = "Carpeta de src/crop-lambda (con node_modules ya instalado)"
  type        = string
}

variable "build_dir" {
  description = "Carpeta donde se escriben los .zip"
  type        = string
}
