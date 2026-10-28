resource "aws_ecr_repository" "web" {
  name                 = "${local.resource_prefix}-web"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
    Component   = "web"
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "${local.resource_prefix}-worker"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
    Component   = "worker"
  }
}

resource "aws_ecr_repository" "client" {
  name                 = "${local.resource_prefix}-client"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = var.environment
    Component   = "client"
  }
}

