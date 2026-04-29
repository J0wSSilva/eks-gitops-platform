# =============================================================================
# Local Environment - Values (MiniStack)
# Custo: $0 (tudo local via containers)
# =============================================================================

aws_region          = "us-east-1"
ministack_endpoint  = "http://localhost:4566"
cluster_name        = "eks-gitops-local"
environment         = "local"

# VPC
vpc_cidr             = "10.99.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs = ["10.99.1.0/24", "10.99.2.0/24"]
public_subnet_cidrs  = ["10.99.101.0/24", "10.99.102.0/24"]

# EKS
cluster_version = "1.29"

node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    scaling_config = {
      desired_size = 2
      min_size     = 1
      max_size     = 3
    }
    disk_size = 20
    labels    = { role = "general" }
    taints    = []
  }
}

# ECR
ecr_repository_names = ["eks-gitops-platform/demo-app"]

# RDS (MiniStack spawna PostgreSQL real)
enable_rds = true
