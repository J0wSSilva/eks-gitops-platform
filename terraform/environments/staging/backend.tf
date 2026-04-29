# =============================================================================
# Backend - Staging Environment
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "eks-gitops-platform-tfstate"
    key            = "environments/staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eks-gitops-platform-tflock"
    encrypt        = true
  }
}
