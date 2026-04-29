# =============================================================================
# Local Environment Variables
# Adaptadas para uso com MiniStack
# =============================================================================

variable "aws_region" {
  description = "Região AWS emulada"
  type        = string
  default     = "us-east-1"
}

variable "ministack_endpoint" {
  description = "Endpoint do MiniStack"
  type        = string
  default     = "http://localhost:4566"
}

variable "cluster_name" {
  description = "Nome do cluster EKS (local)"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser: local, dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
}

variable "cluster_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.29"
}

variable "node_groups" {
  description = "Configuração dos node groups"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    scaling_config = object({
      desired_size = number
      min_size     = number
      max_size     = number
    })
    disk_size = number
    labels    = map(string)
    taints    = list(any)
  }))
}

variable "ecr_repository_names" {
  description = "Lista de repositórios ECR"
  type        = list(string)
}

variable "enable_rds" {
  description = "Habilitar RDS (PostgreSQL real via MiniStack)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
