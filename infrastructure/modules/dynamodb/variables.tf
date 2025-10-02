variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform locks"
  type        = string
}
variable "environment" {
  description = "Environment (dev, test, prod) for resources"
  type        = string
  default     = "dev"
}
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "default_project"
}
variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "default_owner"
}