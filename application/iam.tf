data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_ec2" {
  name = "${local.resource_prefix}-ec2-role"

  description = "runtime role for ec2"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "app_ec2" {
  name = "${local.resource_prefix}-ec2-profile"
  role = aws_iam_role.app_ec2.name
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role = aws_iam_role.app_ec2.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "app_runtime" {
  statement {
    sid    = "ListMediaBuckets"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads"
    ]

    resources = [
      for bucket in aws_s3_bucket.media : bucket.arn
    ]
  }

  statement {
    sid    = "ReadWriteMediaObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      for bucket in aws_s3_bucket.media : "${bucket.arn}/*"
    ]
  }

  statement {
    sid    = "ProcessVideoPreparationJobs"
    effect = "Allow"

    actions = [
      "sqs:GetQueueUrl",
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [
      aws_sqs_queue.video_preparation.arn
    ]
  }
}

resource "aws_iam_policy" "app_runtime" {
  name        = "${local.resource_prefix}-app-runtime"
  description = "s3 and sqs access"

  policy = data.aws_iam_policy_document.app_runtime.json
}

resource "aws_iam_role_policy_attachment" "app_runtime" {
  role = aws_iam_role.app_ec2.name

  policy_arn = aws_iam_policy.app_runtime.arn
}