output "state_bucket_name" {
  description = "s3 bucket for storing terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "current_aws_account_id" {
  description = "current aws account"
  value       = data.aws_caller_identity.current.account_id
}