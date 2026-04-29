#!/bin/bash
# =============================================================================
# setup-local.sh — Bootstrap completo do ambiente local
# Sobe MiniStack + Kind + Terraform + ArgoCD + Demo App
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo "================================================================"
echo "  EKS GitOps Platform — Local Environment Setup"
echo "  Using: MiniStack + Kind + ArgoCD"
echo "================================================================"
echo ""

# ----- Pré-requisitos -----
echo "▶ Verificando pré-requisitos..."
command -v docker &>/dev/null || err "Docker não encontrado"
command -v kubectl &>/dev/null || err "kubectl não encontrado"
command -v kind &>/dev/null || err "kind não encontrado"
command -v terraform &>/dev/null || err "terraform não encontrado"
command -v tflocal &>/dev/null || err "tflocal não encontrado (pip install terraform-local)"
log "Pré-requisitos OK"

# ----- 1. MiniStack -----
echo ""
echo "▶ [1/5] Subindo MiniStack..."
cd "$SCRIPT_DIR"
docker compose -f docker-compose.local.yml down 2>/dev/null || true
docker compose -f docker-compose.local.yml up -d

echo "   Aguardando MiniStack ficar pronto..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:4566/_ministack/health &>/dev/null; then
    log "MiniStack pronto ($(curl -s http://localhost:4566/_ministack/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"version\"]} - {len(d[\"services\"])} services')"))"
    break
  fi
  sleep 2
done
curl -sf http://localhost:4566/_ministack/health &>/dev/null || err "MiniStack não respondeu após 60s"

# ----- 2. Terraform -----
echo ""
echo "▶ [2/5] Aplicando Terraform no MiniStack..."
cd "$PROJECT_DIR/terraform/environments/local"
rm -f localstack_providers_override.tf terraform.tfstate terraform.tfstate.backup
curl -s -X POST http://localhost:4566/_ministack/reset > /dev/null
tflocal init -input=false > /dev/null 2>&1
tflocal apply -auto-approve -input=false 2>&1 | grep -E "(Apply complete|Error:)"
log "Terraform aplicado"

# ----- 3. Kind Cluster -----
echo ""
echo "▶ [3/5] Criando cluster Kind..."
docker rm -f eks-gitops-local-control-plane eks-gitops-local-worker eks-gitops-local-worker2 2>/dev/null || true
kind delete cluster --name eks-gitops-local 2>/dev/null || true
kind create cluster --config "$SCRIPT_DIR/kind-config.yaml"
kubectl wait --for=condition=Ready nodes --all --timeout=60s
log "Kind cluster pronto ($(kubectl get nodes --no-headers | wc -l) nodes)"

# ----- 4. ArgoCD -----
echo ""
echo "▶ [4/5] Instalando ArgoCD..."
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts 2>&1 | grep -c "serverside-applied" | xargs -I{} echo "   {} recursos aplicados"
kubectl -n argocd rollout status deployment argocd-server --timeout=120s
ARGO_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
log "ArgoCD instalado"

# ----- 5. Demo App -----
echo ""
echo "▶ [5/5] Deployando Pod Dashboard..."
cd "$PROJECT_DIR"

# Build da imagem local
echo "   Construindo imagem pod-info..."
docker build -f app/Dockerfile.local -t eks-gitops-platform/pod-info:latest app/ > /dev/null 2>&1
kind load docker-image eks-gitops-platform/pod-info:latest --name eks-gitops-local > /dev/null 2>&1
log "Imagem carregada no cluster"

# Deploy via Kustomize (sem ArgoCD auto-sync para evitar conflito)
kubectl apply -k kubernetes/overlays/local 2>/dev/null
kubectl -n demo-app rollout status deployment/demo-app --timeout=90s

# Aplica imagem pod-info (overlay reflete no Git, mas localmente forçamos)
kubectl -n demo-app set image deployment/demo-app demo-app=eks-gitops-platform/pod-info:latest > /dev/null 2>&1
kubectl -n demo-app patch deployment demo-app --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Never"},{"op":"add","path":"/spec/template/spec/containers/0/env","value":[{"name":"POD_NAMESPACE","valueFrom":{"fieldRef":{"fieldPath":"metadata.namespace"}}},{"name":"NODE_NAME","valueFrom":{"fieldRef":{"fieldPath":"spec.nodeName"}}},{"name":"POD_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}}]}]' > /dev/null 2>&1
kubectl -n demo-app rollout status deployment/demo-app --timeout=60s
log "Pod Dashboard deployado (3 réplicas)"

# ----- Resumo -----
echo ""
echo "================================================================"
echo -e "  ${GREEN}Ambiente local pronto!${NC}"
echo "================================================================"
echo ""
echo "  MiniStack:      http://localhost:4566/_ministack/health"
echo "  ArgoCD UI:      https://localhost:9090 (após port-forward)"
echo "  Pod Dashboard:  http://localhost:8081 (após port-forward)"
echo ""
echo "  ArgoCD Login:"
echo "    User: admin"
echo "    Pass: $ARGO_PASS"
echo ""
echo "  Port-forwards:"
echo "    kubectl -n argocd port-forward svc/argocd-server 9090:443 &"
echo "    kubectl -n demo-app port-forward svc/demo-app 8081:80 &"
echo ""
echo "  Cleanup: ./cleanup-local.sh"
echo "================================================================"
