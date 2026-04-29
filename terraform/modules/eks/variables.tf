# =============================================================================
# EKS Module - Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Cluster
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.cluster_name))
    error_message = "cluster_name deve ter 3-40 chars, começar com letra, apenas lowercase, números e hífens."
  }
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS (ex: 1.29)"
  type        = string
  default     = "1.29"

  validation {
    condition     = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.cluster_version))
    error_message = "cluster_version deve ser >= 1.27 (versões anteriores estão deprecated)."
  }
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser: dev, staging ou prod."
  }
}

# -----------------------------------------------------------------------------
# Networking (recebidos do módulo VPC)
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID da VPC onde o cluster será criado"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para os worker nodes"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Mínimo de 2 subnets privadas para HA do EKS."
  }
}

# -----------------------------------------------------------------------------
# Node Groups
# -----------------------------------------------------------------------------

variable "node_groups" {
  description = "Configuração dos managed node groups (spot e on-demand)"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string # ON_DEMAND ou SPOT
    scaling_config = object({
      desired_size = number
      min_size     = number
      max_size     = number
    })
    disk_size = number
    labels    = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))

  default = {
    general = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      scaling_config = {
        desired_size = 2
        min_size     = 1
        max_size     = 4
      }
      disk_size = 50
      labels    = { role = "general" }
      taints    = []
    }
    spot = {
      instance_types = ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
      capacity_type  = "SPOT"
      scaling_config = {
        desired_size = 1
        min_size     = 0
        max_size     = 6
      }
      disk_size = 50
      labels    = { role = "spot" }
      taints    = []
    }
  }
}

# -----------------------------------------------------------------------------
# EKS Add-ons
# -----------------------------------------------------------------------------

variable "cluster_addons" {
  description = "Add-ons gerenciados do EKS (vpc-cni, coredns, kube-proxy, ebs-csi)"
  type = map(object({
    version                  = optional(string)
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
  }))

  default = {
    vpc-cni = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }
}

# -----------------------------------------------------------------------------
# Access & Security
# -----------------------------------------------------------------------------

variable "cluster_endpoint_public_access" {
  description = "Permite acesso ao API server do EKS pela internet"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Permite acesso ao API server do EKS via rede privada da VPC"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs permitidos para acesso público ao API server (ex: IP do escritório)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_encryption" {
  description = "Habilita encryption at rest dos Secrets do K8s com KMS"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "cluster_log_types" {
  description = "Tipos de log do control plane enviados ao CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "Dias de retenção dos logs do control plane no CloudWatch"
  type        = number
  default     = 14
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags adicionais para todos os recursos"
  type        = map(string)
  default     = {}
}
