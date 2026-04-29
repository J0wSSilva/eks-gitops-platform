# =============================================================================
# Environment Outputs
# =============================================================================

# VPC
output "vpc_id" {
  description = "ID da VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "nat_public_ips" {
  description = "IPs públicos do NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# EKS
output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do API server"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Comando para configurar kubectl"
  value       = module.eks.configure_kubectl
}

output "oidc_provider_arn" {
  description = "ARN do OIDC provider (para IRSA)"
  value       = module.eks.oidc_provider_arn
}

# ECR
output "ecr_repository_urls" {
  description = "URLs dos repositórios ECR"
  value       = module.ecr.repository_urls
}

# RDS
output "rds_endpoint" {
  description = "Endpoint do RDS (se habilitado)"
  value       = var.enable_rds ? module.rds[0].endpoint : null
}

output "rds_secret_arn" {
  description = "ARN do secret com credenciais do RDS"
  value       = var.enable_rds ? module.rds[0].secret_arn : null
}
