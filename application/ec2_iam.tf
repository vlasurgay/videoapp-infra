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


# iam for ec2 to access ssm
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role = aws_iam_role.app_ec2.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# iam for ec2 to access s3
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
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility"
    ]
    resources = [
      aws_sqs_queue.video_preparation_queue.arn
    ]
  }
}

resource "aws_iam_policy" "app_runtime" {
  name        = "${local.resource_prefix}-app-runtime"
  description = "s3 and sqs access"

  policy = data.aws_iam_policy_document.app_runtime.json
}

resource "aws_iam_role_policy_attachment" "app_runtime" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = aws_iam_policy.app_runtime.arn
}


# iam for ec2 to access runtime parameters in ssm
data "aws_iam_policy_document" "parameters_runtime" {
  statement {
    sid    = "ReadRuntimeConfiguration"
    effect = "Allow"

    actions = [
      "ssm:GetParametersByPath"
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_prefix}/runtime/*"
    ]
  }

  statement {
    sid    = "ReadDatabasePassword"
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      aws_ssm_parameter.db_password.arn
    ]
  }

  statement {
    sid    = "DecryptSecureStringThroughSSM"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "parameters_runtime" {
  name        = "${local.resource_prefix}-parameters-runtime"
  description = "access runtime parameters from ssm"

  policy = data.aws_iam_policy_document.parameters_runtime.json
}

resource "aws_iam_role_policy_attachment" "parameters_runtime" {
  role       = aws_iam_role.app_ec2.name
  policy_arn = aws_iam_policy.parameters_runtime.arn
}


# iam for ec2 to access ecr
data "aws_iam_policy_document" "ecr_pull" {
  for_each = local.repositories

  statement {
    sid    = "AuthenticateToECR"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "PullApplicationImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = each.value.aws_ecr_repository_arns
  }
}

resource "aws_iam_policy" "ecr_pull" {
  for_each = local.repositories

  name        = "${local.resource_prefix}-${each.key}-ecr-pull"
  description = "allow ec2 pull images of ${each.key} from ecr"
  policy      = data.aws_iam_policy_document.ecr_pull[each.key].json

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  for_each = local.repositories

  role       = aws_iam_role.app_ec2.name
  policy_arn = aws_iam_policy.ecr_pull[each.key].arn
}