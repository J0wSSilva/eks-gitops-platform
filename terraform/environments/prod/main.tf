# =============================================================================
# Prod Environment - Root Module
# Production-grade: Multi-AZ, encryption, deletion protection, HA
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

  # Prod: 1 NAT por AZ para HA
  single_nat_gateway = var.single_nat_gateway

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

  # Prod: acesso público restrito, privado habilitado
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # TROCAR pelo CIDR da VPN!

  # Prod: encryption habilitada e logs com retenção longa
  enable_cluster_encryption  = true
  cluster_log_retention_days = 90

  tags = var.tags
}

# =============================================================================
# ECR
# =============================================================================

module "ecr" {
  source = "../../modules/ecr"

  repository_names = var.ecr_repository_names
  environment      = var.environment

  # Prod: IMMUTABLE obrigatório, retenção alta
  image_tag_mutability = "IMMUTABLE"
  max_image_count      = 50
  expire_untagged_days = 14

  tags = var.tags
}

# =============================================================================
# RDS
# =============================================================================

module "rds" {
  source = "../../modules/rds"
  count  = var.enable_rds ? 1 : 0

  cluster_name               = var.cluster_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  # Prod: instância maior, Multi-AZ, proteção total
  instance_class          = var.rds_instance_class
  multi_az                = true
  deletion_protection     = true
  skip_final_snapshot     = false
  backup_retention_period = 14

  tags = var.tags
}
