# =============================================================================
# RDS Module - Main
# PostgreSQL instance with security group, subnet group and managed credentials
# =============================================================================

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "rds"
    Project     = "eks-gitops-platform"
  })
}

# =============================================================================
# DB Subnet Group (define em quais subnets o RDS pode ser colocado)
# =============================================================================

resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${var.environment}-db-subnet"
  })
}

# =============================================================================
# Security Group (acesso ao RDS apenas pelos EKS nodes)
# =============================================================================

resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-rds-sg"
  })
}

resource "aws_security_group_rule" "rds_ingress" {
  count = var.environment != "local" ? length(var.allowed_security_group_ids) : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL from EKS nodes"
}

# =============================================================================
# RDS Password (gerenciado pelo Secrets Manager — nunca fica no state)
# =============================================================================

resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${var.cluster_name}/${var.environment}/rds-master-password"
  description             = "Master password for RDS ${var.cluster_name}-${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id = aws_secretsmanager_secret.rds_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.database_name
  })
}

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|:,.<>?"
}

# =============================================================================
# RDS PostgreSQL Instance
# =============================================================================

resource "aws_db_instance" "this" {
  identifier = "${var.cluster_name}-${var.environment}"

  # Engine
  engine         = "postgres"
  engine_version = var.engine_version

  # Compute & Storage
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  # Database
  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result
  port     = 5432

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Backup
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  # Protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_name}-${var.environment}-final-${formatdate("YYYY-MM-DD", timestamp())}"

  # Monitoring
  performance_insights_enabled = var.environment == "prod" ? true : false

  # Upgrades
  auto_minor_version_upgrade  = true
  apply_immediately           = var.environment != "prod" ? true : false
  copy_tags_to_snapshot       = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${var.environment}"
  })

  lifecycle {
    ignore_changes = [password]
  }
}
