# =============================================================================
# ECR Module - Outputs
# =============================================================================

output "repository_urls" {
  description = "Map de nome → URL do repositório ECR (usado no CI/CD para docker push)"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map de nome → ARN do repositório ECR (usado em IAM policies)"
  value = {
    for name, repo in aws_ecr_repository.this : name => repo.arn
  }
}

output "registry_id" {
  description = "ID do registry ECR (Account ID)"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
