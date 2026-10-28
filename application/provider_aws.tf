data "aws_caller_identity" "current" {}

locals {
  resource_prefix = "${var.project_name}-${var.environment}-${data.aws_caller_identity.current.account_id}"
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