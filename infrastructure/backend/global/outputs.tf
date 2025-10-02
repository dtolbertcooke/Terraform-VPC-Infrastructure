output "state_bucket_name" {
  value = module.s3_backend.bucket_name
}

output "dynamodb_table_name" {
  value = module.dynamodb_backend.dynamodb_table_name
}

output "region" {
  value = var.region
}