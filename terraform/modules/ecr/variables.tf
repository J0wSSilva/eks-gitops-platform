# =============================================================================
# ECR Module - Variables
# =============================================================================

variable "repository_names" {
  description = "Lista de nomes dos repositórios ECR a serem criados"
  type        = list(string)
  default     = ["eks-gitops-platform/demo-app"]
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["local", "dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser: dev, staging ou prod."
  }
}

variable "image_tag_mutability" {
  description = "Mutabilidade das tags. IMMUTABLE impede sobrescrever tags (recomendado para prod)"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability deve ser MUTABLE ou IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Habilita scan de vulnerabilidades automático ao fazer push de imagem"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Número máximo de imagens a manter no repositório (lifecycle policy)"
  type        = number
  default     = 30

  validation {
    condition     = var.max_image_count >= 5
    error_message = "max_image_count deve ser >= 5 para manter histórico mínimo."
  }
}

variable "expire_untagged_days" {
  description = "Dias para expirar imagens sem tag (limpeza de builds intermediários)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags adicionais para todos os recursos"
  type        = map(string)
  default     = {}
}
