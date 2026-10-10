output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "dlq_alarm_name" {
  value = aws_cloudwatch_metric_alarm.dlq_messages.alarm_name
}
