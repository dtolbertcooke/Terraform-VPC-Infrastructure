# remote state is populated by the script in .github/workflows/vpc.yml
terraform {
  backend "s3" {
  }
}