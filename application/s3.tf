locals {
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
}

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

data "aws_iam_policy_document" "media_bucket_tls_uploads" {

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.media["uploads"].arn,
      "${aws_s3_bucket.media["uploads"].arn}/*"
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

data "aws_iam_policy_document" "media_bucket_tls_processed" {

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.media["processed"].arn,
      "${aws_s3_bucket.media["processed"].arn}/*"
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

  statement {
    sid    = "AllowCloudFrontReadProcessedMedia"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.media["processed"].arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.media.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "media_policy_uploads" {
  bucket = aws_s3_bucket.media["uploads"].id
  policy = data.aws_iam_policy_document.media_bucket_tls_uploads.json
}

resource "aws_s3_bucket_policy" "media_policy_processed" {
  bucket = aws_s3_bucket.media["processed"].id
  policy = data.aws_iam_policy_document.media_bucket_tls_processed.json
}

resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.media["uploads"].id

  queue {
    id        = "video-multipart-upload-completed"
    queue_arn = aws_sqs_queue.video_preparation_queue.arn

    events = [
      "s3:ObjectCreated:CompleteMultipartUpload"
    ]

    filter_prefix = "temp/uploads/"
  }

  depends_on = [
    aws_sqs_queue.video_preparation_queue
  ]
}