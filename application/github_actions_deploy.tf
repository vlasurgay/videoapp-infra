locals {
  repositories = {
    videoapp = {
      oidc_subject = "repo:vlasurgay/videoapp:ref:refs/heads/master"
      description  = "github actions role for videoapp"

      aws_ecr_repository_arns = [
        aws_ecr_repository.web.arn,
        aws_ecr_repository.worker.arn
      ]
    }
    videoapp_client = {
      oidc_subject = "repo:vlasurgay/videoapp-client:ref:refs/heads/master"
      description  = "github actions role for videoapp-client"

      aws_ecr_repository_arns = [
        aws_ecr_repository.client.arn
      ]
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "github_actions_trust" {
  for_each = local.repositories

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        each.value.oidc_subject
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  for_each = local.repositories

  name               = "${local.resource_prefix}-github-actions-deploy-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust[each.key].json

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "github_actions_deploy" {
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
    sid    = "PublishApplicationImages"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = each.value.aws_ecr_repository_arns
  }

  statement {
    sid    = "AllowDeploymentDocument"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
    ]
  }

  statement {
    sid    = "DeployOnlyToVideoAppInstances"
    effect = "Allow"

    actions = [
      "ssm:SendCommand"
    ]

    resources = [
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = [var.project_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Environment"
      values   = [var.environment]
    }
  }

  statement {
    sid    = "ReadDeploymentStatus"
    effect = "Allow"

    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  for_each = local.repositories

  name        = "${local.resource_prefix}-github-actions-deploy-${each.key}"
  description = "allow github actions to store images and deploy through ssm"
  policy      = data.aws_iam_policy_document.github_actions_deploy[each.key].json

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
    Module      = each.key
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  for_each = local.repositories

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = aws_iam_policy.github_actions_deploy[each.key].arn
}