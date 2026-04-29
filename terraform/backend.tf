# =============================================================================
# Backend Configuration (referência)
#
# IMPORTANTE: Este arquivo é apenas documentação.
# Cada environment (dev/staging/prod) tem seu próprio backend.tf
# apontando para uma key diferente no mesmo bucket S3.
#
# Para criar o bucket e a tabela DynamoDB pela PRIMEIRA vez,
# execute o bootstrap abaixo antes de rodar terraform init:
#
# aws s3api create-bucket \
#   --bucket eks-gitops-platform-tfstate \
#   --region us-east-1
#
# aws s3api put-bucket-versioning \
#   --bucket eks-gitops-platform-tfstate \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket eks-gitops-platform-tfstate \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "aws:kms"
#       },
#       "BucketKeyEnabled": true
#     }]
#   }'
#
# aws s3api put-public-access-block \
#   --bucket eks-gitops-platform-tfstate \
#   --public-access-block-configuration \
#     BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
#
# aws dynamodb create-table \
#   --table-name eks-gitops-platform-tflock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
#
# =============================================================================

# Backend real configurado em cada environment:
# terraform/environments/dev/backend.tf
# terraform/environments/staging/backend.tf
# terraform/environments/prod/backend.tf
