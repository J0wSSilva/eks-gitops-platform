#!/bin/bash
# =============================================================================
# cleanup-local.sh — Destrói todo o ambiente local
# Remove Kind + MiniStack + volumes
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo "================================================================"
echo "  EKS GitOps Platform — Cleanup Local Environment"
echo "================================================================"
echo ""

# ----- Kind -----
echo "▶ Removendo cluster Kind..."
kind delete cluster --name eks-gitops-local 2>/dev/null && log "Kind cluster removido" || warn "Kind cluster não encontrado"

# ----- MiniStack -----
echo "▶ Removendo MiniStack..."
cd "$SCRIPT_DIR"
docker compose -f docker-compose.local.yml down -v 2>/dev/null && log "MiniStack removido" || warn "MiniStack não encontrado"

# ----- Terraform state -----
echo "▶ Limpando Terraform state..."
rm -rf "$SCRIPT_DIR/../terraform/environments/local/.terraform" \
       "$SCRIPT_DIR/../terraform/environments/local/terraform.tfstate"* \
       "$SCRIPT_DIR/../terraform/environments/local/.terraform.lock.hcl" \
       "$SCRIPT_DIR/../terraform/environments/local/localstack_providers_override.tf"
log "Terraform state limpo"

# ----- Port-forwards -----
echo "▶ Matando port-forwards..."
pkill -f "kubectl.*port-forward" 2>/dev/null && log "Port-forwards encerrados" || warn "Nenhum port-forward ativo"

echo ""
echo "================================================================"
echo -e "  ${GREEN}✅ Ambiente local removido com sucesso!${NC}"
echo "================================================================"
echo ""
echo "  Para recriar: ./setup-local.sh"
echo "================================================================"
