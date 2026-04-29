# =============================================================================
# Prod Environment - Values
# Foco: HA, segurança, performance
# Custo estimado: ~$550/mês (EKS $73 + NAT $105 + Nodes $280 + RDS $65 + misc)
# =============================================================================

aws_region   = "us-east-1"
cluster_name = "eks-gitops-prod"
environment  = "prod"

# VPC - 3 AZs para HA, CIDR diferente
vpc_cidr             = "10.30.0.0/16"
azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
public_subnet_cidrs  = ["10.30.101.0/24", "10.30.102.0/24", "10.30.103.0/24"]
single_nat_gateway   = false # 1 NAT por AZ para HA

# EKS
cluster_version = "1.29"

node_groups = {
  general = {
    instance_types = ["m5.xlarge"]
    capacity_type  = "ON_DEMAND"
    scaling_config = {
      desired_size = 3
      min_size     = 3
      max_size     = 6
    }
    disk_size = 100
    labels    = { role = "general" }
    taints    = []
  }
  spot = {
    instance_types = ["m5.xlarge", "m5a.xlarge", "m5.2xlarge", "m5a.2xlarge"]
    capacity_type  = "SPOT"
    scaling_config = {
      desired_size = 2
      min_size     = 0
      max_size     = 10
    }
    disk_size = 100
    labels    = { role = "spot" }
    taints    = []
  }
}

# ECR
ecr_repository_names = ["eks-gitops-platform/demo-app"]

# RDS
enable_rds         = true
rds_instance_class = "db.t3.medium"

# Tags
tags = {
  Team        = "platform"
  CostCenter  = "prod"
  Compliance  = "soc2"
}
