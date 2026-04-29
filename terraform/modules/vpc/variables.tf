# =============================================================================
# VPC Module - Variables
# =============================================================================

variable "cluster_name" {
  description = "Nome do cluster EKS. Usado para tags obrigatórias nas subnets"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.cluster_name))
    error_message = "cluster_name deve ter 3-40 chars, começar com letra, apenas lowercase, números e hífens."
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

variable "vpc_cidr" {
  description = "Bloco CIDR principal da VPC (ex: 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr deve ser um bloco CIDR válido."
  }
}

variable "azs" {
  description = "Lista de Availability Zones (mínimo 2 para HA)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Mínimo de 2 AZs para alta disponibilidade."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas (uma por AZ). Nodes EKS ficam aqui"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas (uma por AZ). Load Balancers ficam aqui"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Habilita NAT Gateway para subnets privadas acessarem internet"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Usar apenas 1 NAT Gateway (economia ~$65/mês por NAT economizado). Para prod, usar false"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Habilita DNS hostnames na VPC (obrigatório para EKS)"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Habilita DNS support na VPC (obrigatório para EKS)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags adicionais para todos os recursos"
  type        = map(string)
  default     = {}
}
