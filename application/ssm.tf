locals {

  parameter_prefix = "/${var.project_name}/${var.environment}"

  runtime_parameters = {
    AWS_REGION                        = var.aws_region
    AWS_S3_UPLOADS_BUCKET             = aws_s3_bucket.media["uploads"].bucket
    AWS_S3_PROCESSED_BUCKET           = aws_s3_bucket.media["processed"].bucket
    AWS_S3_PRESIGNED_URL_LIFETIME_SEC = "180"
    MAX_PART_UPLOAD_SIZE              = "15728640"

    CDN_DOMAIN_NAME = "https://${aws_cloudfront_distribution.media.domain_name}"

    AWS_SQS_QUEUE_NAME = aws_sqs_queue.video_preparation_queue.name

    DB_HOST = "videoapp-db"
    DB_PORT = "5432"
    DB_NAME = var.db_name
    DB_USER = var.db_user

    AI_MODE_ENABLED = tostring(var.ai_mode_enabled)
  }
}

resource "aws_ssm_parameter" "runtime" {
  for_each = local.runtime_parameters

  name  = "${local.parameter_prefix}/runtime/${each.key}"
  type  = "String"
  value = each.value

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  name        = "${local.parameter_prefix}/secrets/DB_PASSWORD"
  description = "db postgres password"
  type        = "SecureString"

  value_wo         = var.db_password
  value_wo_version = var.db_password_version

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}