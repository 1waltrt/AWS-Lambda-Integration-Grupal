output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "sg_upload_id" {
  value = aws_security_group.upload_lambda.id
}

output "sg_crop_id" {
  value = aws_security_group.crop_lambda.id
}

output "sg_vpce_sqs_id" {
  value = aws_security_group.vpce_sqs.id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.this[*].id
}
