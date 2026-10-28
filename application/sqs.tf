locals {
  video_preparation_queues = {
    video_preparation_queue = {
      name    = "${local.resource_prefix}-video-preparation"
      purpose = "queue dedicated to video preparation jobs"
    }
    video_preparation_dlq = {
      name    = "${local.resource_prefix}-video-preparation-dlq"
      purpose = "failed video preparation jobs"
    }
  }
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

resource "aws_sqs_queue" "video_preparation_queue" {
  name = local.video_preparation_queues.video_preparation_queue.name

  visibility_timeout_seconds = 3600
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_preparation_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name    = local.video_preparation_queues.video_preparation_queue.name
    Purpose = local.video_preparation_queues.video_preparation_queue.purpose
  }
}

data "aws_iam_policy_document" "video_preparation_queue" {
  statement {
    sid    = "AllowUploadsBucketNotifications"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      aws_sqs_queue.video_preparation_queue.arn
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        aws_s3_bucket.media["uploads"].arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "video_preparation_queue_policy" {
  queue_url = aws_sqs_queue.video_preparation_queue.url
  policy    = data.aws_iam_policy_document.video_preparation_queue.json
}