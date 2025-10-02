variable "personal_ip" {
  description = "What is your personal IP address for SSH access"
  type        = string
}
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}
variable "environment" {
  description = "Environment tag for resources"
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
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "azs" {
  description = "Availability zones for the VPC"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"] # two azs by default
}