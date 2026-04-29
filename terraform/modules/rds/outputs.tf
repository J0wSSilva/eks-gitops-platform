# =============================================================================
# RDS Module - Outputs
# =============================================================================

output "endpoint" {
  description = "Endpoint de conexão do RDS (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname do RDS (sem porta)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta do RDS"
  value       = aws_db_instance.this.port
}

output "database_name" {
  description = "Nome do database"
  value       = aws_db_instance.this.db_name
}

output "master_username" {
  description = "Username do master user"
  value       = aws_db_instance.this.username
}

output "security_group_id" {
  description = "ID do Security Group do RDS (para permitir acesso de outros SGs)"
  value       = aws_security_group.rds.id
}

output "secret_arn" {
  description = "ARN do secret no Secrets Manager contendo as credenciais"
  value       = aws_secretsmanager_secret.rds_password.arn
}

output "secret_name" {
  description = "Nome do secret no Secrets Manager"
  value       = aws_secretsmanager_secret.rds_password.name
}
