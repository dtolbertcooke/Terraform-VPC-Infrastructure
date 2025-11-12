# S3 bucket for Terraform State module
resource "random_id" "random_hex" {
  byte_length = 5
}

module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.4.0"

  bucket        = "${var.bucket_name}-${var.environment}-${random_id.random_hex.hex}"
  force_destroy = true
  versioning = {
    enabled = true
  }
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    ManagedBy   = "Terraform"
  }
}
