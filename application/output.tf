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
  value       = aws_sqs_queue.video_preparation_queue.url
}

output "video_preparation_queue_arn" {
  description = "arn of the video preparation queue"
  value       = aws_sqs_queue.video_preparation_queue.arn
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

#ssm
output "runtime_parameter_path" {
  description = "ssm param path for runtime variables"
  value       = "${local.parameter_prefix}/runtime"
}

output "db_password_parameter_name" {
  description = "ssm param for db password"
  value       = aws_ssm_parameter.db_password.name
}

#cdn
output "media_cdn_domain_name" {
  description = "cloudfront hostname for s3-processed"
  value       = aws_cloudfront_distribution.media.domain_name
}

output "media_cdn_base_url" {
  description = "https base url for s3-processed"
  value       = "https://${aws_cloudfront_distribution.media.domain_name}"
}

#ecr
output "ecr_web_repository_url" {
  description = "ecr rep url for videoapp-web"
  value       = aws_ecr_repository.web.repository_url
}

output "ecr_worker_repository_url" {
  description = "ecr rep url for videoapp-worker"
  value       = aws_ecr_repository.worker.repository_url
}

output "ecr_client_repository_url" {
  description = "ecr rep url for videoapp-client"
  value       = aws_ecr_repository.client.repository_url
}

#github
output "github_actions_deploy_role_videoapp_arn" {
  description = "iam videoapp role assumed by github actions through oidc"
  value       = aws_iam_role.github_actions["videoapp"].arn
}

output "github_actions_deploy_role_videoapp_client_arn" {
  description = "iam videoapp-client role assumed by github actions through oidc"
  value       = aws_iam_role.github_actions["videoapp_client"].arn
}