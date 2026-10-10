output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (donde corren las Lambdas)"
  value       = aws_subnet.private[*].id
}

output "sg_upload_id" {
  description = "Security group de upload-lambda"
  value       = aws_security_group.upload_lambda.id
}

output "sg_crop_id" {
  description = "Security group de crop-lambda"
  value       = aws_security_group.crop_lambda.id
}
