# Phase 3: Terraform + Ansible Infrastructure as Code (IaC)

**Points: 15 pts** (Terraform: 7 pts, Ansible: 5 pts, Integration: 3 pts)

## Overview

Phase 3 implements Infrastructure as Code (IaC) using Terraform for Kubernetes resource provisioning and Ansible for environment configuration. This ensures:
- ✅ Reproducible infrastructure
- ✅ Version-controlled deployments
- ✅ Automated configuration management
- ✅ Consistent environments (dev → prod)

---

## Architecture

```
┌─────────────────┐
│  Git Repository │
│  ├─ Terraform/  │
│  ├─ Ansible/    │
│  └─ Jenkinsfile │
└────────┬────────┘
         │
         ▼
    ┌─────────────┐
    │  Jenkins    │
    │  Stage 6    │
    └────┬────────┘
         │
    ┌────┴─────────┬──────────────┐
    ▼              ▼              ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐
│Terraform│  │ Ansible │  │   Kubectl    │
│(IaC)    │  │(Config) │  │  (Deploy)    │
└────┬────┘  └────┬────┘  └──────┬───────┘
     │            │              │
     ▼            ▼              ▼
  Kubernetes Cluster Infrastructure
  ├─ Namespace (medicine-stock)
  ├─ ConfigMap
  ├─ Secret
  ├─ ServiceAccount + RBAC
  ├─ NetworkPolicy
  └─ Application Deployment
```

---

## Directory Structure

```
medicine-stock-devops/
├── terraform/
│   ├── main.tf                  # Main infrastructure code
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   ├── terraform.tfvars.example # Example variables
│   ├── .terraform/              # Terraform state directory
│   ├── .terraform.lock.hcl      # Dependency lock file
│   ├── terraform.tfstate        # Current state
│   └── terraform.tfstate.backup # State backup
│
├── ansible/
│   ├── playbook.yml            # Main playbook
│   ├── inventory               # Host inventory
│   └── roles/                  # (Optional) Ansible roles
│
└── scripts/
    ├── deploy-terraform.sh     # Terraform deployment script
    └── deploy-ansible.sh       # Ansible execution script
```

---

## Terraform Configuration

### File: `terraform/main.tf`

**Resources Provisioned:**

#### 1. Kubernetes Namespace
```hcl
resource "kubernetes_namespace_v1" "medicine_namespace"
```
- **Purpose**: Isolates application resources
- **Name**: `medicine-stock` (default, configurable via `variables.tf`)
- **Labels**: Applied for identification and filtering

#### 2. ConfigMap
```hcl
resource "kubernetes_config_map_v1" "app_config"
```
- **Purpose**: Store non-sensitive configuration
- **Key-Value Pairs**:
  - `DB_PATH`: Database path (`/app/medicine.db`)
  - `PYTHONUNBUFFERED`: Python output buffering (`1`)
  - `LOG_LEVEL`: Application log level (configurable)
  - `ENVIRONMENT`: Environment name (dev/staging/prod)

#### 3. Secret
```hcl
resource "kubernetes_secret_v1" "app_secrets"
```
- **Purpose**: Store sensitive credentials
- **Sensitive Data**:
  - `DOCKER_REGISTRY_USERNAME`: Docker registry credentials
  - `DOCKER_REGISTRY_PASSWORD`: Registry password/token
- **Type**: Opaque (base64 encoded)
- **Note**: Values come from Terraform variables (marked as `sensitive=true`)

#### 4. ServiceAccount
```hcl
resource "kubernetes_service_account_v1" "medicine_stock"
```
- **Purpose**: Identity for pods
- **Name**: `medicine-stock-sa`
- **Namespace**: Created in `medicine-stock` namespace

#### 5. Role
```hcl
resource "kubernetes_role_v1" "medicine_stock"
```
- **Purpose**: Define permissions for pods
- **Permissions**:
  - Read ConfigMaps and Secrets
  - Read pod status and logs
- **Scope**: Namespace-level (medicine-stock)

#### 6. RoleBinding
```hcl
resource "kubernetes_role_binding_v1" "medicine_stock"
```
- **Purpose**: Bind Role to ServiceAccount
- **Links**: ServiceAccount → Role for permission assignment

#### 7. NetworkPolicy (Optional)
```hcl
resource "kubernetes_network_policy_v1" "medicine_stock"
```
- **Purpose**: Enforce network traffic policies
- **Rules**:
  - **Ingress**: Allow traffic only from same namespace
  - **Egress**: Allow traffic to same namespace and DNS
- **Security Benefit**: Network segmentation and isolation

### File: `terraform/variables.tf`

**Variables:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `namespace` | string | `medicine-stock` | Kubernetes namespace name |
| `kubeconfig_path` | string | `~/.kube/config` | Path to kubeconfig file |
| `environment` | string | `dev` | Environment (dev/staging/prod) |
| `log_level` | string | `INFO` | Application log level |
| `docker_username` | string | `` | Docker registry username (sensitive) |
| `docker_password` | string | `` | Docker registry password (sensitive) |

### File: `terraform/outputs.tf`

**Outputs:**

| Output | Type | Value |
|--------|------|-------|
| `namespace_name` | string | Kubernetes namespace name |
| `service_account_name` | string | ServiceAccount name |
| `config_map_name` | string | ConfigMap name |
| `secret_name` | string | Secret name (sensitive) |
| `role_name` | string | Role name |
| `deployment_info` | object | Complete deployment metadata |

---

## Ansible Configuration

### File: `ansible/playbook.yml`

**Playbook Tasks:**

#### Pre-Tasks
- Display playbook information
- Show target host and namespace

#### Main Tasks

##### 1. Check Prerequisites
```yaml
- Check kubectl availability
- Display kubectl version
- Check Kubernetes cluster connectivity
```

##### 2. Initialize Terraform
```yaml
- terraform init
- terraform validate
- terraform plan -out=tfplan
```

##### 3. Apply Terraform
```yaml
- terraform apply -auto-approve tfplan
- terraform output -json (display results)
```

##### 4. Verify Namespace Creation
```yaml
- kubectl get namespace
- Display namespace details
```

##### 5. Verify RBAC Setup
```yaml
- Check ServiceAccount
- Check Role
- Check RoleBinding
```

##### 6. Prometheus Namespace (Optional)
```yaml
- Create or verify Prometheus namespace
```

##### 7. List Deployed Resources
```yaml
- kubectl get all (display all resources)
```

##### 8. Verify Network Policies
```yaml
- kubectl get networkpolicies
```

#### Post-Tasks
- Display setup summary
- Show next steps for application deployment

### File: `ansible/inventory`

**Inventory:**

```ini
[kubernetes]
localhost ansible_connection=local
```

- **Group**: `kubernetes` - Target Kubernetes cluster
- **Host**: `localhost` with local connection (for local cluster)
- **Customization**: Update for remote clusters

---

## Integration with Jenkinsfile

### Stage 6: Deploy to Kubernetes

The Jenkinsfile Stage 6 integrates Terraform + Ansible + kubectl:

```groovy
stage('6. Deploy to Kubernetes') {
    when {
        expression { params.DEPLOY_K8S == true }
    }
    steps {
        script {
            // Step 1: Terraform Infrastructure Provisioning
            sh '''
                cd terraform
                terraform init
                terraform validate
                terraform plan -out=tfplan
                terraform apply -auto-approve tfplan
                terraform output -json | jq .
                cd ..
            '''
            
            // Step 2: Ansible Configuration
            sh '''
                cd ansible
                ansible --version
                ansible-playbook -i inventory playbook.yml -v
                cd ..
            '''
            
            // Step 3: Application Deployment
            sh '''
                kubectl set image deployment/medicine-stock ...
                kubectl apply -f k8s/service.yaml ...
                kubectl rollout status deployment/medicine-stock ...
            '''
        }
    }
}
```

**Execution Flow:**
1. **Terraform** provisions Kubernetes resources (namespace, RBAC, ConfigMap, Secret)
2. **Ansible** validates infrastructure and applies configuration
3. **kubectl** deploys the application using manifests

---

## Deployment Instructions

### Prerequisites

#### Local Machine
```bash
# Install Terraform
brew install terraform  # macOS
choco install terraform # Windows (admin)

# Install Ansible
pip install ansible

# Install kubectl
brew install kubectl    # macOS
# OR from: https://kubernetes.io/docs/tasks/tools/

# Install jq (for JSON formatting)
brew install jq        # macOS
choco install jq       # Windows
```

#### Kubernetes Cluster
- Running Kubernetes cluster (local: minikube, Docker Desktop, or remote)
- `~/.kube/config` properly configured
- Cluster admin access (to create namespaces, RBAC)

### Setup Steps

#### Step 1: Configure Terraform Variables

```bash
# Copy example to actual config
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your values
# vim terraform/terraform.tfvars
```

**Example terraform.tfvars:**
```hcl
namespace        = "medicine-stock"
kubeconfig_path  = "~/.kube/config"
environment      = "development"
log_level        = "DEBUG"
docker_username  = "your-docker-username"
docker_password  = "your-docker-token"
```

#### Step 2: Initialize Terraform

```bash
cd terraform
terraform init
terraform validate
cd ..
```

#### Step 3: Configure Ansible

Edit `ansible/inventory` for your target (usually localhost for local cluster):

```ini
[kubernetes]
localhost ansible_connection=local
```

#### Step 4: Manual Deployment (Before Jenkins)

```bash
# Option A: Use provided scripts
./scripts/deploy-terraform.sh
./scripts/deploy-ansible.sh

# Option B: Manual commands
cd terraform
terraform plan -out=tfplan
terraform apply tfplan
cd ..

cd ansible
ansible-playbook -i inventory playbook.yml -v
cd ..
```

#### Step 5: Verify Deployment

```bash
# Check namespace
kubectl get namespace medicine-stock

# Check resources
kubectl get all -n medicine-stock

# Check ConfigMap
kubectl get cm -n medicine-stock

# Check Secret
kubectl get secret -n medicine-stock

# Check RBAC
kubectl get sa,role,rb -n medicine-stock

# Check NetworkPolicy
kubectl get networkpolicy -n medicine-stock
```

---

## Jenkins Trigger

### Automatic (via Jenkinsfile)

When Jenkins job is triggered with parameter `DEPLOY_K8S=true`:

1. **Pipeline continues** through stages 1-5 (normal CI/CD)
2. **Stage 6 executes**:
   - Terraform provisions infrastructure
   - Ansible configures environment
   - kubectl deploys application

### Manual Trigger

```bash
# Via Jenkins API
curl -X POST \
  http://jenkins-url/job/medicine-stock/buildWithParameters \
  -u username:token \
  -F DEPLOY_K8S=true \
  -F PUSH_TO_REGISTRY=true \
  -F IMAGE_TAG=1.0.0
```

---

## State Management

### Terraform State Files

| File | Purpose |
|------|---------|
| `terraform.tfstate` | Current infrastructure state (managed by Terraform) |
| `terraform.tfstate.backup` | Previous state backup |
| `.terraform.lock.hcl` | Dependency lock file (commit to Git) |
| `.terraform/` | Terraform plugins and modules |

**Best Practices:**
- ✅ Commit `.terraform.lock.hcl` to Git
- ✅ Backup `terraform.tfstate` regularly
- ❌ Never commit sensitive data in state
- ❌ Don't commit `.terraform/` directory
- ✅ Use remote state for team environments (Terraform Cloud, S3, etc.)

### State Locking (Team Environments)

For shared state, enable backend locking:

```hcl
terraform {
  backend "s3" {
    bucket         = "medicine-stock-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## Troubleshooting

### Terraform Issues

#### Error: "Failed to get credentials"
```bash
# Solution: Check kubeconfig
kubectl config view
export KUBECONFIG=~/.kube/config
terraform apply
```

#### Error: "Namespace already exists"
```bash
# Solution: Import existing namespace
terraform import kubernetes_namespace_v1.medicine_namespace medicine-stock

# Or destroy and recreate
terraform destroy
terraform apply
```

#### Error: "Permission denied"
```bash
# Solution: Check cluster admin access
kubectl auth can-i create namespaces --as=system:admin
kubectl auth can-i create roles --as=system:admin
```

### Ansible Issues

#### Error: "ansible: command not found"
```bash
# Solution: Install Ansible
pip install ansible

# Verify installation
ansible --version
```

#### Error: "Kubernetes cluster not accessible"
```bash
# Solution: Verify cluster connection
kubectl cluster-info
kubectl get nodes
```

#### Error: "Playbook syntax error"
```bash
# Solution: Validate playbook
ansible-playbook -i ansible/inventory ansible/playbook.yml --syntax-check
```

### Kubernetes Issues

#### Namespace stuck in "Terminating"
```bash
# Solution: Remove finalizers
kubectl patch ns medicine-stock -p '{"metadata":{"finalizers":null}}'
```

#### ServiceAccount not found
```bash
# Solution: Re-apply Terraform
terraform taint kubernetes_service_account_v1.medicine_stock
terraform apply
```

---

## Advanced Topics

### Remote State Management

Store Terraform state in S3 for team collaboration:

```hcl
# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "medicine-stock-tf-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### Workspace Separation

Use Terraform workspaces for environment separation:

```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspace
terraform workspace select prod

# Deploy with environment-specific variables
terraform apply -var-file="prod.tfvars"
```

### Ansible Roles

Organize Ansible code with roles:

```
ansible/
├── roles/
│   ├── kubernetes-setup/
│   │   ├── tasks/main.yml
│   │   ├── templates/
│   │   └── defaults/main.yml
│   ├── monitoring/
│   │   └── tasks/main.yml
│   └── security/
│       └── tasks/main.yml
└── playbook.yml
```

### Policy as Code

Add Terraform validation with Sentinel:

```hcl
# sentinel.hcl
policy "require_labels" {
  enforcement_level = "hard-mandatory"
}
```

---

## Success Criteria

✅ **Phase 3 Complete When:**

1. **Terraform Configuration**
   - ✓ Namespace created
   - ✓ ConfigMap deployed
   - ✓ Secret created
   - ✓ ServiceAccount provisioned
   - ✓ Role and RoleBinding applied
   - ✓ NetworkPolicy enabled

2. **Ansible Configuration**
   - ✓ Terraform initialized and validated
   - ✓ Resources provisioned
   - ✓ RBAC verified
   - ✓ Cluster connectivity confirmed

3. **Jenkins Integration**
   - ✓ Stage 6 executes Terraform
   - ✓ Stage 6 executes Ansible
   - ✓ Stage 6 deploys application
   - ✓ Build completes successfully

4. **Verification**
   - ✓ Run: `kubectl get ns medicine-stock`
   - ✓ Run: `kubectl get cm,secret -n medicine-stock`
   - ✓ Run: `kubectl get sa,role,rb -n medicine-stock`

---

## Related Resources

- [Terraform Kubernetes Provider Docs](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Ansible Kubernetes Module](https://docs.ansible.com/ansible/latest/collections/kubernetes/core/index.html)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)

---

## Next Phase

**Phase 4: Kubernetes Deployment**
- Update `k8s/deployment.yaml` with image, replicas, probes
- Configure `k8s/service.yaml` with NodePort
- Test application deployment and scaling

**Phase 5: Monitoring (Already Complete)**
- Prometheus metrics collection ✓
- Grafana dashboards ✓
- Log aggregation (Optional)

**Bonus: Presentation**
- Architecture diagram
- Live demo script
- Q&A preparation

---

## Authors & Notes

**Created**: May 15, 2026
**Status**: Phase 3 Implementation Complete
**Points**: 15 pts (Terraform + Ansible + Integration)

**Key Achievements:**
- ✅ Infrastructure as Code (Terraform)
- ✅ Configuration Management (Ansible)
- ✅ Kubernetes Integration (kubectl)
- ✅ Jenkins Pipeline Integration
- ✅ RBAC & Security Setup
- ✅ Reproducible Infrastructure

