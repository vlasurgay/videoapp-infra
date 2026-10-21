#bootstrap
output "current_aws_account_id" {
  description = "current aws account"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "aws region"
  value       = var.aws_region
}


#s3
output "uploads_bucket_name" {
  description = "s3 bucket for storing raw uploads"
  value       = aws_s3_bucket.media["uploads"].bucket
}

output "processed_bucket_name" {
  description = "s3 bucket for storing processed data"
  value       = aws_s3_bucket.media["processed"].bucket
}

output "video_preparation_queue_url" {
  description = "url of the video preparation queue"
  value       = aws_sqs_queue.video_preparation.url
}

output "video_preparation_queue_arn" {
  description = "arn of the video preparation queue"
  value       = aws_sqs_queue.video_preparation.arn
}

output "video_preparation_dlq_arn" {
  description = "arn of the dlq"
  value       = aws_sqs_queue.video_preparation_dlq.arn
}

#ec2
output "app_instance_id" {
  description = "ec2 instance id"
  value       = aws_instance.app.id
}

output "app_public_ip" {
  description = "public ec2 instance ip"
  value       = aws_instance.app.public_ip
}