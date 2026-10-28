#bootstrap
variable "expected_aws_account_id" {
  description = "aws account id where all resources will be managed"
  type        = string
}

variable "aws_region" {
  description = "aws region"
  type        = string
}

variable "project_name" {
  description = "name of the project"
  type        = string
  default     = "videoapp"
}

variable "environment" {
  description = "deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "must be either dev or prod"
  }
}

#s3
variable "allowed_frontend_origins" {
  description = "valid origins to access S3"
  type        = list(string)
  default     = ["http://localhost:4200"]
}

#ec2
variable "vpc_cidr" {
  description = "cidr of the vpc"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "cidr of the public subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "ec2_ssm_ami_path" {
  type    = string
  default = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

variable "ec2_instance_type" {
  description = "ec2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ec2_root_volume_size" {
  description = "size of EC2 root ebs volume in gb"
  type        = number
  default     = 30

  validation {
    condition     = var.ec2_root_volume_size >= 20
    error_message = "size of ebs volume must be at least 20 gb"
  }
}

variable "ai_mode_enabled" {
  description = "run app whether with or without AI-tools. AI requires more paid resources"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "db postgres name"
  type        = string
  default     = "videoapp"
}

variable "db_user" {
  description = "db postgres user"
  type        = string
  default     = "videoapp"
}

variable "db_password" {
  description = "db password"
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
}

variable "db_password_version" {
  description = "should be incremented while updating password"
  type        = number
  default     = 1
}
