# =============================================================================
# Staging Environment - Values
# Foco: espelho de prod com recursos menores
# Custo estimado: ~$230/mês (EKS $73 + NAT $35 + Nodes $132 + misc)
# =============================================================================

aws_region   = "us-east-1"
cluster_name = "eks-gitops-staging"
environment  = "staging"

# VPC - CIDR diferente de dev (permite peering futuro)
vpc_cidr             = "10.20.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
public_subnet_cidrs  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
single_nat_gateway   = true

# EKS
cluster_version = "1.29"

node_groups = {
  general = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    scaling_config = {
      desired_size = 2
      min_size     = 2
      max_size     = 4
    }
    disk_size = 50
    labels    = { role = "general" }
    taints    = []
  }
  spot = {
    instance_types = ["t3.large", "t3a.large", "t3.xlarge"]
    capacity_type  = "SPOT"
    scaling_config = {
      desired_size = 1
      min_size     = 0
      max_size     = 4
    }
    disk_size = 50
    labels    = { role = "spot" }
    taints    = []
  }
}

# ECR
ecr_repository_names = ["eks-gitops-platform/demo-app"]

# RDS
enable_rds         = true
rds_instance_class = "db.t3.small"

# Tags
tags = {
  Team        = "platform"
  CostCenter  = "staging"
}
