# =============================================================================
# Environment Variables
# Valores default são sobrescritos pelo terraform.tfvars
# =============================================================================

variable "aws_region" {
  description = "Região AWS para deploy"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser: dev, staging ou prod."
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

variable "single_nat_gateway" {
  description = "Usar apenas 1 NAT Gateway (economia)"
  type        = bool
  default     = true
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
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

variable "ecr_repository_names" {
  description = "Nomes dos repositórios ECR"
  type        = list(string)
  default     = ["eks-gitops-platform/demo-app"]
}

variable "enable_rds" {
  description = "Habilita o módulo RDS"
  type        = bool
  default     = false
}

variable "rds_instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "tags" {
  description = "Tags adicionais"
  type        = map(string)
  default     = {}
}
