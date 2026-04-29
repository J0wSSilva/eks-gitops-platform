# =============================================================================
# VPC Module - Outputs
# Exporta IDs e ARNs necessários para os módulos EKS, RDS e ECR
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Bloco CIDR da VPC"
  value       = aws_vpc.this.cidr_block
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

output "private_subnet_ids" {
  description = "Lista de IDs das subnets privadas (para EKS nodes e RDS)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Lista de IDs das subnets públicas (para Load Balancers)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_cidrs" {
  description = "Lista de CIDRs das subnets privadas"
  value       = aws_subnet.private[*].cidr_block
}

output "public_subnet_cidrs" {
  description = "Lista de CIDRs das subnets públicas"
  value       = aws_subnet.public[*].cidr_block
}

# -----------------------------------------------------------------------------
# NAT Gateway
# -----------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "IDs dos NAT Gateways criados"
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "IPs públicos dos NAT Gateways (útil para whitelist em firewalls externos)"
  value       = aws_eip.nat[*].public_ip
}

# -----------------------------------------------------------------------------
# Route Tables (para associações externas, ex: VPC peering)
# -----------------------------------------------------------------------------

output "private_route_table_ids" {
  description = "IDs das route tables privadas"
  value       = aws_route_table.private[*].id
}

output "public_route_table_id" {
  description = "ID da route table pública"
  value       = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Metadata (útil para debug e referência cruzada)
# -----------------------------------------------------------------------------

output "azs" {
  description = "Availability Zones utilizadas"
  value       = var.azs
}
