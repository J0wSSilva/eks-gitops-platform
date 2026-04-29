# =============================================================================
# Backend - Dev Environment
# State isolado: cada env tem sua key no S3
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "eks-gitops-platform-tfstate"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-platform-tflock"
    encrypt        = true
  }
}
