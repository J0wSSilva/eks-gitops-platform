# =============================================================================
# Dev Environment - Values
# Foco: custo mínimo, iteração rápida
# Custo estimado: ~$150/mês (EKS $73 + NAT $35 + Nodes $72 + misc)
# =============================================================================

aws_region   = "us-east-1"
cluster_name = "eks-gitops-dev"
environment  = "dev"

# VPC - /16 com subnets /24
vpc_cidr             = "10.10.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
public_subnet_cidrs  = ["10.10.101.0/24", "10.10.102.0/24"]
single_nat_gateway   = true # 1 NAT = economia de ~$35/mês

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
    disk_size = 30
    labels    = { role = "general" }
    taints    = []
  }
}

# ECR
ecr_repository_names = ["eks-gitops-platform/demo-app"]

# RDS (desabilitado por default em dev para economizar)
enable_rds         = false
rds_instance_class = "db.t3.micro"

# Tags
tags = {
  Team        = "platform"
  CostCenter  = "dev"
}
