output "api_endpoint_url" {
  description = "URL base del stage $default (puede terminar en '/'; el entorno agrega /upload)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.this.id
}
