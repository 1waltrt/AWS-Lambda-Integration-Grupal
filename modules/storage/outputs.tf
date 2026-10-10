output "bucket_name" {
  value = aws_s3_bucket.images.id
}

output "bucket_arn" {
  value = aws_s3_bucket.images.arn
}

output "queue_arn" {
  value = aws_sqs_queue.main.arn
}

output "queue_url" {
  value = aws_sqs_queue.main.id
}

output "dlq_name" {
  value = aws_sqs_queue.dlq.name
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
