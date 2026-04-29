# =============================================================================
# RDS Module - Variables
# =============================================================================

variable "cluster_name" {
  description = "Nome do cluster (usado como prefixo para naming)"
  type        = string
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
# Networking
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para o DB subnet group"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Mínimo de 2 subnets para o DB subnet group (Multi-AZ)."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups permitidos a acessar o RDS (ex: SG dos EKS nodes)"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

variable "engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento alocado em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Armazenamento máximo para autoscaling em GB (0 = desabilitado)"
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Nome do database a ser criado"
  type        = string
  default     = "demoapp"
}

variable "master_username" {
  description = "Username do master user do RDS"
  type        = string
  default     = "dbadmin"
}

# -----------------------------------------------------------------------------
# Backup & Maintenance
# -----------------------------------------------------------------------------

variable "backup_retention_period" {
  description = "Dias de retenção de backups automáticos"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Janela de backup (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Janela de manutenção (UTC)"
  type        = string
  default     = "sun:04:30-sun:05:30"
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------

variable "multi_az" {
  description = "Habilita Multi-AZ (standby em outra AZ para failover automático)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Proteção contra delete acidental (recomendado em prod)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final ao destruir (false em prod)"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Habilita encryption at rest"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags adicionais para todos os recursos"
  type        = map(string)
  default     = {}
}
