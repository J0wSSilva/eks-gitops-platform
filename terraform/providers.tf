# =============================================================================
# Provider Configuration
# Nota: este arquivo serve como referência. Cada environment/ tem seu próprio
# provider configurado com a região específica.
# =============================================================================

provider "aws" {
  # Região será definida no environment (dev/staging/prod)
  # Usar: export AWS_REGION=us-east-1 ou no terraform.tfvars

  default_tags {
    tags = {
      Project   = "eks-gitops-platform"
      ManagedBy = "terraform"
    }
  }
}
