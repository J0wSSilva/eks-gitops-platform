# =============================================================================
# Dev Environment - Root Module
# Orquestra todos os módulos: VPC → EKS → ECR → RDS (opcional)
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "eks-gitops-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
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
  single_nat_gateway   = var.single_nat_gateway

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

  # Dev: acesso público aberto para facilitar desenvolvimento
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Dev: logs com retenção curta
  cluster_log_retention_days = 7

  tags = var.tags
}

# =============================================================================
# ECR
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_names = var.ecr_repository_names
  environment      = var.environment

  # Dev: tags mutáveis para facilitar iteração rápida
  image_tag_mutability = "MUTABLE"
  max_image_count      = 10
  expire_untagged_days = 3

  tags = var.tags
}

# =============================================================================
# RDS (opcional - habilitado via enable_rds)
# =============================================================================

module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  cluster_name               = var.cluster_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  instance_class      = var.rds_instance_class
  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

  tags = var.tags
}
