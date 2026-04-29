# 🏗 Arquitetura

> Visão completa de como as peças se encaixam — do commit do desenvolvedor até o pod rodando no cluster.

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Fluxo GitOps (Detalhado)](#-fluxo-gitops-detalhado)
- [Topologia de Rede](#-topologia-de-rede)
- [Isolamento por Ambiente](#-isolamento-por-ambiente)
- [Stack Tecnológica](#-stack-tecnológica)
- [Arquitetura Local](#-arquitetura-local)

---

## Visão Geral

O diagrama abaixo mostra todas as camadas da plataforma e como elas se conectam:

```mermaid
graph TB
    %% Developer Workflow
    subgraph Developer["👨‍💻 Desenvolvedor"]
        DEV[Developer] -->|git push| GH[GitHub Repository]
    end

    %% CI/CD
    subgraph CICD["⚙️ GitHub Actions CI/CD"]
        GH -->|trigger| CI[CI Pipeline]
        CI -->|lint + test + scan| SEC[Security Gate]
        SEC -->|build & push| ECR[Amazon ECR]
        CI -->|terraform plan| TF[Terraform Pipeline]
        TF -->|apply| AWS_INFRA[AWS Infrastructure]
        ECR -->|update image tag| DEPLOY[Deploy Pipeline]
        DEPLOY -->|kustomize edit| GH
    end

    %% GitOps
    subgraph GitOps["🔄 GitOps (ArgoCD)"]
        GH -->|watch repo| ARGO[ArgoCD]
        ARGO -->|sync| K8S[EKS Cluster]
        ARGO -->|app-of-apps| APPS[ApplicationSets]
        APPS -->|per-env| DEV_NS[dev namespace]
        APPS -->|per-env| STG_NS[staging namespace]
        APPS -->|per-env| PROD_NS[prod namespace]
    end

    %% AWS
    subgraph AWS["☁️ AWS Cloud"]
        subgraph VPC["VPC (Multi-AZ)"]
            subgraph Public["Public Subnets"]
                ALB[Application Load Balancer]
                NAT[NAT Gateway]
            end
            subgraph Private["Private Subnets"]
                K8S
                RDS[(RDS PostgreSQL)]
            end
        end
        SM[AWS Secrets Manager]
        S3[S3 Terraform State]
        KMS[KMS Encryption]
    end

    %% Observability
    subgraph Observability["📊 Observabilidade"]
        PROM[Prometheus] -->|scrape| K8S
        GRAF[Grafana] -->|query| PROM
        AM[Alertmanager] -->|route| SLACK[Slack]
        AM -->|critical| PD[PagerDuty]
        PROM -->|alerts| AM
    end

    %% Security
    subgraph Security["🔒 Segurança"]
        ESO[External Secrets Operator] -->|fetch| SM
        ESO -->|inject| K8S
        NETPOL[Network Policies] -->|enforce| K8S
        RBAC[K8s RBAC] -->|authorize| K8S
        OIDC[GitHub OIDC] -->|federate| IAM[IAM Roles]
    end

    %% Connections
    ALB -->|route traffic| K8S
    K8S -->|connect| RDS
    IAM -->|assume role| ECR
    IAM -->|assume role| S3

    classDef aws fill:#FF9900,stroke:#232F3E,color:#232F3E
    classDef k8s fill:#326CE5,stroke:#fff,color:#fff
    classDef security fill:#D63AFF,stroke:#fff,color:#fff
    classDef observability fill:#00C7B7,stroke:#fff,color:#fff
    classDef cicd fill:#2088FF,stroke:#fff,color:#fff

    class ECR,RDS,SM,S3,KMS,ALB,NAT,IAM aws
    class K8S,ARGO,APPS,DEV_NS,STG_NS,PROD_NS,ESO,NETPOL,RBAC k8s
    class SEC,OIDC security
    class PROM,GRAF,AM observability
    class CI,TF,DEPLOY cicd
```

---

## 🔄 Fluxo GitOps (Detalhado)

O que acontece em cada etapa, desde o push até o pod novo receber tráfego:

```mermaid
sequenceDiagram
    participant Dev as Desenvolvedor
    participant GH as GitHub
    participant CI as CI Pipeline
    participant ECR as Amazon ECR
    participant Argo as ArgoCD
    participant K8s as EKS Cluster

    Dev->>GH: git push (feature branch)
    GH->>CI: Trigger CI workflow
    CI->>CI: Lint (ruff + hadolint)
    CI->>CI: Test (pytest + coverage)
    CI->>CI: Security scan (Trivy)
    CI->>ECR: Build & push image (sha-abc123)
    CI->>GH: Update kustomization.yaml (new image tag)

    Note over GH,Argo: ArgoCD sync loop (3 min)

    Argo->>GH: Detecta mudança nos manifests
    Argo->>K8s: Aplica manifests (namespace do ambiente)
    K8s->>K8s: Rolling update (zero downtime)
    K8s-->>Argo: Health check passed ✓

    Note over Dev,K8s: Promoção: dev → staging → prod

    Dev->>GH: Merge PR to main
    GH->>CI: Trigger deploy workflow
    CI->>K8s: Deploy staging (automático)
    CI->>CI: Aguarda approval gate
    Dev->>CI: Aprova deploy em produção
    CI->>K8s: Deploy prod (gate manual)
```

### Por que GitOps?

- **Auditabilidade**: todo deploy tem um commit associado
- **Rollback trivial**: `git revert` desfaz qualquer mudança
- **Consistência**: o cluster sempre reflete o que está no Git
- **Segurança**: ninguém precisa de `kubectl` em produção

---

## 🌐 Topologia de Rede

Cada ambiente tem uma VPC isolada com 3 Availability Zones. O tráfego segue um caminho bem definido:

```mermaid
graph LR
    subgraph VPC["VPC 10.x.0.0/16"]
        subgraph AZ1["AZ-a"]
            PUB1["Public 10.x.1.0/24<br/>ALB, NAT"]
            PRIV1["Private 10.x.10.0/24<br/>EKS Nodes"]
            DB1["Database 10.x.20.0/24<br/>RDS Primary"]
        end
        subgraph AZ2["AZ-b"]
            PUB2["Public 10.x.2.0/24<br/>ALB"]
            PRIV2["Private 10.x.11.0/24<br/>EKS Nodes"]
            DB2["Database 10.x.21.0/24<br/>RDS Standby"]
        end
        subgraph AZ3["AZ-c"]
            PUB3["Public 10.x.3.0/24<br/>ALB"]
            PRIV3["Private 10.x.12.0/24<br/>EKS Nodes"]
            DB3["Database 10.x.22.0/24<br/>RDS (prod)"]
        end
    end

    INET[Internet] --> ALB2[ALB]
    ALB2 --> PUB1 & PUB2 & PUB3
    PUB1 --> PRIV1
    PUB2 --> PRIV2
    PUB3 --> PRIV3
    PRIV1 --> DB1
    PRIV2 --> DB2
```

### Decisões de design

- **Subnets públicas** só têm ALB e NAT Gateway — nenhum pod roda aqui
- **Subnets privadas** hospedam os nodes EKS — sem acesso direto da internet
- **Subnets database** são ainda mais isoladas — só pods com Network Policy podem acessar
- **NAT Gateway** permite que pods busquem imagens do ECR e façam chamadas externas

---

## 🏢 Isolamento por Ambiente

| Aspecto     | Dev                       | Staging                  | Prod                     |
| ----------- | ------------------------- | ------------------------ | ------------------------ |
| VPC CIDR    | `10.10.0.0/16`            | `10.20.0.0/16`           | `10.30.0.0/16`           |
| Node Type   | `t3.medium`               | `t3.large`               | `m5.xlarge`              |
| Node Count  | 2 (ON_DEMAND)             | 2-4 (SPOT + OD)          | 3-6 (SPOT + OD)          |
| NAT Gateway | Single                    | Single                   | Multi-AZ                 |
| RDS         | Single-AZ, `db.t3.medium` | Single-AZ, `db.t3.large` | Multi-AZ, `db.r6g.large` |
| Replicas    | 1                         | 2                        | 3-10 (HPA)               |
| Deploy Gate | Automático                | Automático               | Aprovação manual         |
| RBAC (devs) | Acesso total              | View + debug             | Read-only                |
| Custo est.  | ~$170/mês                 | ~$270/mês                | ~$530/mês                |

### Filosofia

- **Dev** existe para quebrar coisas rápido e aprender — nada é sagrado aqui
- **Staging** é onde validamos que tudo funciona junto antes de ir para prod
- **Prod** é conservador por design — deploy manual, menos permissões, mais réplicas

---

## 🔧 Stack Tecnológica

| Camada        | Tecnologia                   | Papel na plataforma              |
| ------------- | ---------------------------- | -------------------------------- |
| IaC           | Terraform 1.7+               | Provisiona e versiona infra      |
| Cloud         | AWS (EKS, ECR, RDS, S3, KMS) | Hospeda tudo                     |
| Orquestração  | Kubernetes 1.29 (EKS)        | Roda e escala os containers      |
| GitOps        | ArgoCD v3                    | Mantém cluster sincronizado      |
| CI/CD         | GitHub Actions               | Automatiza build, test e deploy  |
| Aplicação     | Python 3.12                  | App demo (Pod Dashboard)         |
| Observability | Prometheus + Grafana         | Métricas, dashboards e alertas   |
| Secrets       | External Secrets Operator    | Injeta secrets de forma segura   |
| Segurança     | Network Policies + RBAC      | Zero Trust por padrão            |

---

## 🏠 Arquitetura Local

Para quem quer explorar sem conta AWS. O `setup-local.sh` provisiona tudo isso:

```
┌─────────────────────────────────────────────────────────┐
│  localhost                                               │
│                                                         │
│  ┌─────────────┐    ┌──────────────────────────────┐   │
│  │  MiniStack  │    │  Kind Cluster                │   │
│  │  :4566      │    │                              │   │
│  │             │    │  ┌────────┐  ┌───────────┐   │   │
│  │  • VPC      │    │  │ ArgoCD │  │ Pod       │   │   │
│  │  • EKS      │    │  │ :9090  │  │ Dashboard │   │   │
│  │  • ECR      │    │  └────────┘  │ :8081     │   │   │
│  │  • RDS      │    │              └───────────┘   │   │
│  │  • IAM      │    │                              │   │
│  │  • S3       │    │  control-plane + 2 workers   │   │
│  └─────────────┘    └──────────────────────────────┘   │
│                                                         │
│  Terraform (tflocal) ──→ MiniStack                      │
│  Kustomize           ──→ Kind                           │
└─────────────────────────────────────────────────────────┘
```

| Componente            | Ferramenta     | Detalhes                             |
| --------------------- | -------------- | ------------------------------------ |
| AWS (49 serviços)     | MiniStack v1.3 | VPC, EKS, ECR, RDS, IAM, S3, etc.   |
| Cluster Kubernetes    | Kind           | 1 control-plane + 2 workers (v1.35)  |
| GitOps                | ArgoCD         | UI em https://localhost:9090         |
| Aplicação             | Pod Dashboard  | Métricas reais do pod em tempo real  |
| Infra                 | tflocal        | 46 recursos Terraform locais         |

### Comandos úteis

```bash
# Subir do zero
cd local && ./setup-local.sh

# Verificar saúde do MiniStack
curl http://localhost:4566/_ministack/health

# Terraform local
cd terraform/environments/local
tflocal plan
tflocal apply -auto-approve

# Derrubar tudo
cd local && ./cleanup-local.sh
```

---

<p align="center">
  <a href="../README.md">← Voltar ao README principal</a>
</p>
