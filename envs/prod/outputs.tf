output "api_endpoint_url" {
  value = module.api.api_endpoint_url
}

output "upload_url" {
  description = "URL completa para subir imágenes (POST)"
  value       = "${trimsuffix(module.api.api_endpoint_url, "/")}/upload"
}

output "bucket_name" {
  value = module.storage.bucket_name
}

output "queue_url" {
  value = module.storage.queue_url
}

output "sns_topic_arn" {
  value = module.observability.sns_topic_arn
}
