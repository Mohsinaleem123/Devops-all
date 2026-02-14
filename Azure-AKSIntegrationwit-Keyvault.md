# 🔐 AKS + Azure Key Vault Integration with Terraform – Zero Secrets in Code

*Complete beginner-friendly guide for Azure Cloud Shell*

---

## 📋 Why This Matters

Traditional secret management in Kubernetes often leads to:
- ❌ Secrets hardcoded in YAML files
- ❌ Secrets exposed in Git repositories
- ❌ Manual rotation and management overhead

**Azure Key Vault + AKS + Terraform** solves this by:
- ✅ Storing secrets securely in Azure Key Vault
- ✅ Mounting secrets directly into pods
- ✅ Zero secrets in your codebase
- ✅ Automatic rotation capabilities
- ✅ Audit logging and access control

---

## 🏗️ Architecture Overview

```
┌─────────────────┐
│   Azure Key     │  ← Secrets stored securely
│   Vault         │    (db-password, API keys, certs)
└────────┬────────┘
         │
    [Managed Identity]
    (AKS System Identity)
         │
┌────────▼────────┐
│      AKS        │  ← Access granted via RBAC
│   Cluster       │    or Access Policies
└────────┬────────┘
         │
    [CSI Driver]
  (Secrets Store)
         │
┌────────▼────────┐
│   Kubernetes    │  ← Secrets mounted as volumes
│     Pod         │    or synced as K8s secrets
└─────────────────┘
```

---

## 🎯 Prerequisites

- ✅ Azure subscription (free tier works)
- ✅ Basic understanding of Kubernetes concepts
- ✅ 30 minutes of your time

---

## 📚 Step-by-Step Implementation

### **Step 1: Launch Azure Cloud Shell**

1. Go to [Azure Portal](https://portal.azure.com)
2. Click the **Cloud Shell** icon (top navigation bar)
3. Select **Bash** environment

```bash
# Verify you're logged in
az account show

# If needed, login
az login
```

### **Step 2: Install Terraform** (if not present)

```bash
# Check if Terraform exists
terraform version

# If not found, install it
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform -y

# Verify installation
terraform version
```

### **Step 3: Create Project Structure**

```bash
# Create project directory
mkdir aks-keyvault-terraform
cd aks-keyvault-terraform

# Create Terraform files
touch main.tf variables.tf outputs.tf
```

### **Step 4: Configure Provider and Backend**

**File: `providers.tf`**
```hcl
terraform {
  required_version = ">= 1.3"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  
  # Optional: State file storage (recommended for teams)
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "tfstateunique123"
  #   container_name       = "tfstate"
  #   key                  = "aks-keyvault.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
```

### **Step 5: Create Resource Group**

**File: `resource-group.tf`**
```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-aks-keyvault-demo"
  location = "East US"
  
  tags = {
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}
```

### **Step 6: Set Up Random Suffix for Uniqueness**

**File: `random.tf`**
```hcl
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

resource "random_password" "db_password" {
  length  = 24
  special = true
  upper   = true
  lower   = true
  number  = true
}
```

### **Step 7: Create Azure Key Vault**

**File: `keyvault.tf`**
```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-aks-demo-${random_integer.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  
  # Two authorization methods - choose one:
  # Option A: RBAC (recommended for new deployments)
  enable_rbac_authorization = true
  
  # Option B: Access Policies (legacy)
  # enable_rbac_authorization = false
  
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  
  tags = azurerm_resource_group.main.tags
}

# Store a secret in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = azurerm_resource_group.main.tags
}
```

### **Step 8: Create AKS Cluster**

**File: `aks.tf`**
```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-keyvault-demo-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-kv-demo"
  
  # Enable OIDC issuer (required for Workload Identity)
  oidc_issuer_enabled = true
  
  # Enable Workload Identity (optional, recommended)
  workload_identity_enabled = true
  
  default_node_pool {
    name       = "system"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
    
    # Enable auto-scaling (optional)
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 3
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  # Enable Azure Key Vault Secrets Provider add-on
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
  
  tags = azurerm_resource_group.main.tags
}
```

### **Step 9: Grant AKS Access to Key Vault**

**Option A: Using RBAC (Recommended)**

**File: `rbac.tf`**
```hcl
# Get the AKS cluster's kubelet identity
data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.main.name
  resource_group_name = azurerm_resource_group.main.name
  
  depends_on = [azurerm_kubernetes_cluster.main]
}

# Assign Key Vault Secrets User role to AKS
resource "azurerm_role_assignment" "aks_to_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
  
  # Alternative: Use kubelet identity
  # principal_id = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
```

**Option B: Using Access Policies (Legacy)**

**File: `access-policy.tf`** (if not using RBAC)
```hcl
resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.main.key_vault_secrets_provider[0].secret_identity[0].object_id
  
  secret_permissions = ["Get", "List"]
}
```

### **Step 10: Create Outputs**

**File: `outputs.tf`**
```hcl
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "connect_to_aks" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "test_secret_command" {
  value = "kubectl exec -it kv-test -- cat /mnt/secrets/db-password"
}
```

### **Step 11: Deploy Infrastructure**

```bash
# Initialize Terraform
terraform init

# Format and validate
terraform fmt
terraform validate

# Preview changes
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
# Or directly: terraform apply -auto-approve

# View outputs
terraform output
```

### **Step 12: Configure kubectl**

```bash
# Get credentials from AKS
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes
```

### **Step 13: Create SecretProviderClass**

Create `secret-provider.yaml`:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-demo
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: kv-aks-demo-34329  # Replace with your KV name
    tenantId: 00000000-0000-0000-0000-000000000000  # Replace with your tenant ID
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
```

Apply it:
```bash
# Replace placeholders with actual values
KEYVAULT_NAME=$(terraform output -raw key_vault_name)
TENANT_ID=$(az account show --query tenantId -o tsv)

sed -i "s/kv-aks-demo-34329/$KEYVAULT_NAME/g" secret-provider.yaml
sed -i "s/00000000-0000-0000-0000-000000000000/$TENANT_ID/g" secret-provider.yaml

# Apply to cluster
kubectl apply -f secret-provider.yaml
```

### **Step 14: Deploy Test Pod**

Create `test-pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kv-test
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: azure-kv-demo
```

Apply and test:
```bash
kubectl apply -f test-pod.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/kv-test --timeout=60s

# Verify secret is mounted
kubectl exec kv-test -- ls -la /mnt/secrets/
kubectl exec kv-test -- cat /mnt/secrets/db-password
```

✅ **Success!** You should see your secret value.

---

## 🔄 Advanced: Sync as Kubernetes Secret

Create `secret-sync.yaml`:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-sync
spec:
  provider: azure
  secretObjects:
  - secretName: db-credentials
    type: Opaque
    data:
    - key: password
      objectName: db-password
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: kv-aks-demo-34329
    tenantId: your-tenant-id
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
```

Create `deployment-sync.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secret
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: nginx:latest
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets"
          readOnly: true
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: azure-kv-sync
```

---

## 🧹 Cleanup Resources

```bash
# Delete test resources
kubectl delete pod kv-test
kubectl delete secretproviderclass azure-kv-demo

# Destroy all infrastructure
terraform destroy -auto-approve
```

---

## 📊 Key Takeaways

| **Concept** | **Why It Matters** |
|-------------|-------------------|
| **Key Vault** | Centralized, secure secret storage with audit logs |
| **Managed Identity** | No credentials to manage or rotate |
| **CSI Driver** | Native Kubernetes integration for secret mounting |
| **Terraform** | Infrastructure as Code - repeatable, versionable deployments |
| **RBAC** | Fine-grained access control without managing keys |

---

## 🚀 Next Steps & Production Hardening

1. **Enable Secret Rotation**
   ```hcl
   key_vault_secrets_provider {
     secret_rotation_enabled = true
     secret_rotation_interval = "2m"
   }
   ```

2. **Use User-Assigned Identity** (more control)
   ```hcl
   identity {
     type = "UserAssigned"
     identity_ids = [azurerm_user_assigned_identity.aks.id]
   }
   ```

3. **Implement Network Security**
   - Enable private endpoints for Key Vault
   - Use AKS authorized IP ranges
   - Enable Azure Policy for AKS

4. **Set Up Monitoring**
   - Enable diagnostics for Key Vault
   - Configure alerts for secret access
   - Use Azure Monitor for containers

5. **CI/CD Integration**
   - Store Terraform state in Azure Storage
   - Use GitHub Actions with OIDC
   - Implement approval gates for production

---

## 🔗 Resources

- 📖 [Azure Key Vault Provider for Secrets Store CSI Driver](https://azure.github.io/secrets-store-csi-driver-provider-azure/)
- 📚 [AKS Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- 🛠️ [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

---

## 💬 Discussion & Questions

Found this helpful? Have questions? Join the discussion:
🔗 [GitHub Discussion](https://github.com/Mohsinaleem123/Devops-all/discussions/1)

---

*Created by [Mohsin Aleem](https://github.com/Mohsinaleem123)* | *Last Updated: February 2025*
