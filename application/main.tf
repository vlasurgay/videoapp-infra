data "aws_caller_identity" "current" {}

locals {
  resource_prefix = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"

  media_buckets = {
    uploads = {
      name    = "${local.resource_prefix}-uploads"
      purpose = "bucket for storing raw uploads"
    }
    processed = {
      name    = "${local.resource_prefix}-processed"
      purpose = "bucket for storing processed data"
    }
  }

  video_preparation_queues = {
    video_preparation = {
      name    = "${local.resource_prefix}-video-preparation"
      purpose = "queue dedicated to video preparation jobs"
    }
    video_preparation_dlq = {
      name    = "${local.resource_prefix}-video-preparation-dlq"
      purpose = "failed video preparation jobs"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_aws_account_id]

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# s3

resource "aws_s3_bucket" "media" {
  for_each = local.media_buckets

  bucket        = each.value.name
  force_destroy = false

  tags = {
    Purpose = each.value.purpose
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  for_each = aws_s3_bucket.media
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  for_each = aws_s3_bucket.media
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "media" {
  for_each = aws_s3_bucket.media
  bucket   = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.media["uploads"].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.media["uploads"].id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.media["uploads"].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST", "PUT"]
    allowed_origins = var.allowed_frontend_origins

    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "media_bucket_tls" {
  for_each = aws_s3_bucket.media

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      each.value.arn,
      "${each.value.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# sqs

resource "aws_s3_bucket_policy" "media" {
  for_each = aws_s3_bucket.media
  bucket   = each.value.id

  policy = data.aws_iam_policy_document.media_bucket_tls[each.key].json
}

resource "aws_sqs_queue" "video_preparation_dlq" {
  name                      = local.video_preparation_queues.video_preparation_dlq.name
  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true

  tags = {
    Name    = local.video_preparation_queues.video_preparation_dlq.name
    Purpose = local.video_preparation_queues.video_preparation_dlq.purpose
  }
}

resource "aws_sqs_queue" "video_preparation" {
  name = local.video_preparation_queues.video_preparation.name

  visibility_timeout_seconds = 3600
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_preparation_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name    = local.video_preparation_queues.video_preparation.name
    Purpose = local.video_preparation_queues.video_preparation.purpose
  }
}