# =============================================================================
# EKS Module - Outputs
# Exporta dados do cluster para consumo por ArgoCD, Helm, kubectl e CI/CD
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster
# -----------------------------------------------------------------------------

output "cluster_id" {
  description = "ID do cluster EKS"
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint do API server do EKS (usado por kubectl e ArgoCD)"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Versão do Kubernetes rodando no cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data para autenticação no cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID do control plane (para regras adicionais)"
  value       = aws_security_group.cluster.id
}

# -----------------------------------------------------------------------------
# OIDC / IRSA
# -----------------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "ARN do OIDC provider (usado para criar IRSA roles)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL do OIDC provider (sem https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# -----------------------------------------------------------------------------
# IAM Roles
# -----------------------------------------------------------------------------

output "cluster_role_arn" {
  description = "ARN da IAM role do control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN da IAM role dos worker nodes"
  value       = aws_iam_role.node.arn
}

# -----------------------------------------------------------------------------
# Node Groups
# -----------------------------------------------------------------------------

output "node_groups" {
  description = "Map com status de cada node group (nome → ARN)"
  value = {
    for k, v in aws_eks_node_group.this : k => {
      arn    = v.arn
      status = v.status
    }
  }
}

# -----------------------------------------------------------------------------
# kubeconfig helper (facilita o primeiro acesso ao cluster)
# -----------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Comando para configurar kubectl local"
  value       = "aws eks update-kubeconfig --region $(aws configure get region) --name ${aws_eks_cluster.this.name}"
}

# -----------------------------------------------------------------------------
# KMS
# -----------------------------------------------------------------------------

output "kms_key_arn" {
  description = "ARN da KMS key usada para encryption dos Secrets (vazio se desabilitado)"
  value       = var.enable_cluster_encryption ? aws_kms_key.eks[0].arn : null
}
