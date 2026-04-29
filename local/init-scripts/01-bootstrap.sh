#!/bin/bash
# Init script: cria recursos base ao iniciar MiniStack
set -e

echo "==> Criando bucket S3 para Terraform state..."
awslocal s3 mb s3://eks-gitops-terraform-state 2>/dev/null || true

echo "==> Criando tabela DynamoDB para Terraform lock..."
awslocal dynamodb create-table \
  --table-name eks-gitops-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || true

echo "==> Criando repositório ECR..."
awslocal ecr create-repository \
  --repository-name eks-gitops-platform/app 2>/dev/null || true

echo "==> Init scripts concluídos!"
