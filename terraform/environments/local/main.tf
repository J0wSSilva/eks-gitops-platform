# =============================================================================
# Local Environment - MiniStack (AWS Emulator)
# Executa toda a infra localmente sem conta AWS real
# Endpoint: http://localhost:4566
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3             = var.ministack_endpoint
    iam            = var.ministack_endpoint
    sts            = var.ministack_endpoint
    ecr            = var.ministack_endpoint
    ec2            = var.ministack_endpoint
    eks            = var.ministack_endpoint
    rds            = var.ministack_endpoint
    dynamodb       = var.ministack_endpoint
    secretsmanager = var.ministack_endpoint
    kms            = var.ministack_endpoint
    cloudwatch     = var.ministack_endpoint
    route53        = var.ministack_endpoint
    elbv2          = var.ministack_endpoint
    autoscaling    = var.ministack_endpoint
  }

  default_tags {
    tags = {
      Project     = "eks-gitops-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "ministack-local"
    }
  }
}

# =============================================================================
# VPC
# =============================================================================

module "vpc" {
  source = "../../modules/vpc"

  cluster_name         = var.cluster_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = true

  tags = var.tags
}

# =============================================================================
# EKS
# =============================================================================

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_groups        = var.node_groups

  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  cluster_log_retention_days           = 1

  # Desabilitar addons (MiniStack não suporta EKS Addons API)
  cluster_addons = {}

  tags = var.tags
}

# =============================================================================
# ECR
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_names     = var.ecr_repository_names
  environment          = var.environment
  image_tag_mutability = "MUTABLE"
  max_image_count      = 5
  expire_untagged_days = 1

  tags = var.tags
}

# =============================================================================
# RDS (MiniStack spawna PostgreSQL real em container)
# =============================================================================

module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  cluster_name               = var.cluster_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  instance_class      = "db.t3.micro"
  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

  tags = var.tags
}
