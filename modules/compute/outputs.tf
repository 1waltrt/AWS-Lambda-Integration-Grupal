output "upload_lambda_arn" {
  value = aws_lambda_function.upload.arn
}

output "upload_lambda_invoke_arn" {
  value = aws_lambda_function.upload.invoke_arn
}

output "upload_lambda_name" {
  value = aws_lambda_function.upload.function_name
}

output "crop_lambda_arn" {
  value = aws_lambda_function.crop.arn
}

output "crop_lambda_name" {
  value = aws_lambda_function.crop.function_name
}
