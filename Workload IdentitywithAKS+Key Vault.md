# 🔐 AKS + Azure Key Vault Integration with Workload Identity

*A comprehensive guide to secure secret management in AKS using Workload Identity*

---

## 📋 Overview

This guide demonstrates how to integrate Azure Key Vault with AKS using **Workload Identity** - the modern, recommended approach for pod-level identity management in AKS.

### Why Workload Identity?

| Feature | Workload Identity | AAD Pod Identity (Legacy) |
|---------|-------------------|--------------------------|
| Architecture | OIDC federation | IMDS interception |
| Components | No in-cluster components | MIC + NMI required |
| Performance | Direct token exchange | Proxy overhead |
| Security | No credential injection | Potential for token theft |
| Scalability | Excellent | Limited |
| Microsoft Recommendation | ✅ **Yes** | ❌ No (maintenance mode) |

---

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────┐
│   Azure AD      │◄────│   OIDC Issuer    │
│                 │     │   (AKS Cluster)  │
└────────┬────────┘     └──────────────────┘
         │                       ▲
         │  Federation           │
         │                       │
┌────────▼────────┐     ┌────────┴─────────┐
│   User-Assigned │     │   ServiceAccount  │
│   Managed Identity│    │   (with annotation)│
└────────┬────────┘     └──────────────────┘
         │                       ▲
         │  RBAC Role             │
         │  Assignment            │ CSI Driver
┌────────▼────────┐     ┌────────┴─────────┐
│   Azure Key     │     │   Kubernetes     │
│   Vault         │◄────│   Pod            │
└─────────────────┘     └──────────────────┘
```

---

## 📚 Step-by-Step Implementation

### **Prerequisites**
- Azure subscription
- Azure CLI installed
- kubectl installed
- Basic understanding of Kubernetes concepts

---

## **Part 1: Set Up Terraform Backend (Optional but Recommended)**

```bash
# Set variables
RG_NAME=rg-terraform-state
LOCATION=eastus
STORAGE_ACCOUNT_NAME=tfstate$RANDOM
CONTAINER_NAME=tfstate

# Create resource group
az group create \
  --name $RG_NAME \
  --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku Standard_LRS \
  --encryption-services blob

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME

echo "Storage Account Name: $STORAGE_ACCOUNT_NAME"
```

---

## **Part 2: Deploy Infrastructure with Terraform**

### **2.1 Create Terraform Configuration Files**

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

  # Optional: Use Azure Storage as backend
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "<STORAGE_ACCOUNT_NAME>"
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

**File: `main.tf`**
```hcl
# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-aks-keyvault-workload"
  location = "East US"
  
  tags = {
    Environment = "Demo"
    ManagedBy   = "Terraform"
    Identity    = "WorkloadIdentity"
  }
}

# Random suffix for uniqueness
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# Random password for demo secret
resource "random_password" "db_password" {
  length  = 24
  special = true
  upper   = true
  lower   = true
  number  = true
}
```

**File: `keyvault.tf`**
```hcl
# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "kv-aks-demo-${random_integer.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  
  # Enable RBAC authorization (recommended)
  enable_rbac_authorization = true
  
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

**File: `user-assigned-identity.tf`**
```hcl
# Create User-Assigned Managed Identity for Workload Identity
resource "azurerm_user_assigned_identity" "workload" {
  name                = "uami-aks-workload-${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  tags = azurerm_resource_group.main.tags
}

# Grant the identity access to Key Vault secrets
resource "azurerm_role_assignment" "identity_to_kv" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
```

**File: `aks.tf`**
```hcl
# AKS Cluster with Workload Identity enabled
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-keyvault-demo-${random_integer.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-kv-demo"
  
  # Enable OIDC issuer (required for Workload Identity)
  oidc_issuer_enabled = true
  
  # Enable Workload Identity
  workload_identity_enabled = true
  
  default_node_pool {
    name       = "system"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
    
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
    secret_rotation_interval = "5m"
  }
  
  tags = azurerm_resource_group.main.tags
}

# Output the OIDC issuer URL
output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
```

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

output "user_assigned_identity_client_id" {
  value = azurerm_user_assigned_identity.workload.client_id
}

output "user_assigned_identity_principal_id" {
  value = azurerm_user_assigned_identity.workload.principal_id
}

output "connect_to_aks" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.main.oidc_issuer_url
}
```

### **2.2 Deploy Infrastructure**

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

# Save outputs for later use
terraform output > terraform-outputs.txt
```

---

## **Part 3: Configure Workload Identity Federation**

### **3.1 Get Required Values**

```bash
# Get OIDC Issuer URL from AKS
OIDC_ISSUER=$(terraform output -raw oidc_issuer_url)
echo "OIDC Issuer: $OIDC_ISSUER"

# Get User-Assigned Identity details
CLIENT_ID=$(terraform output -raw user_assigned_identity_client_id)
PRINCIPAL_ID=$(terraform output -raw user_assigned_identity_principal_id)
IDENTITY_NAME=$(az identity list --resource-group rg-aks-keyvault-workload --query "[0].name" -o tsv)

# Get Key Vault name
KV_NAME=$(terraform output -raw key_vault_name)

echo "Identity Name: $IDENTITY_NAME"
echo "Client ID: $CLIENT_ID"
echo "Key Vault: $KV_NAME"
```

### **3.2 Create Federated Credential**

```bash
# Create federated credential for the service account
az identity federated-credential create \
  --name aks-kv-federation \
  --identity-name $IDENTITY_NAME \
  --resource-group $(terraform output -raw resource_group_name) \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:default:kv-sa \
  --audience api://AzureADTokenExchange
```

### **3.3 Verify Federated Credential**

```bash
# List federated credentials
az identity federated-credential list \
  --identity-name $IDENTITY_NAME \
  --resource-group $(terraform output -raw resource_group_name) \
  -o table
```

---

## **Part 4: Configure Kubernetes Resources**

### **4.1 Connect to AKS**

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes
```

### **4.2 Verify Workload Identity Add-on**

```bash
# Check if workload identity webhook is running
kubectl get pods -n kube-system | grep workload-identity

# Check Secrets Store CSI driver
kubectl get pods -n kube-system | grep secrets-store
```

### **4.3 Create Service Account with Annotation**

Create `service-account.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kv-sa
  namespace: default
  annotations:
    azure.workload.identity/client-id: CLIENT_ID_PLACEHOLDER
```

Apply with client ID:
```bash
# Get client ID if not already set
CLIENT_ID=$(terraform output -raw user_assigned_identity_client_id)

# Create service account with proper client ID
sed "s/CLIENT_ID_PLACEHOLDER/$CLIENT_ID/g" service-account.yaml | kubectl apply -f -

# Verify service account
kubectl get serviceaccount kv-sa -o yaml
```

### **4.4 Create SecretProviderClass**

Create `secret-provider-class.yaml`:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-kv-workload
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"          # Set to false for workload identity
    clientID: "CLIENT_ID_PLACEHOLDER"       # Will be replaced
    keyvaultName: "KV_NAME_PLACEHOLDER"     # Will be replaced
    tenantId: "TENANT_ID_PLACEHOLDER"       # Will be replaced
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
```

Apply with replacements:
```bash
# Get values
CLIENT_ID=$(terraform output -raw user_assigned_identity_client_id)
KV_NAME=$(terraform output -raw key_vault_name)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create SecretProviderClass with proper values
sed -e "s/CLIENT_ID_PLACEHOLDER/$CLIENT_ID/g" \
    -e "s/KV_NAME_PLACEHOLDER/$KV_NAME/g" \
    -e "s/TENANT_ID_PLACEHOLDER/$TENANT_ID/g" \
    secret-provider-class.yaml | kubectl apply -f -

# Verify
kubectl get secretproviderclass azure-kv-workload -o yaml
```

### **4.5 Deploy Test Pod with Workload Identity**

Create `test-pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kv-test-workload
  namespace: default
  labels:
    azure.workload.identity/use: "true"  # This enables workload identity
spec:
  serviceAccountName: kv-sa
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
        secretProviderClass: azure-kv-workload
```

Apply and test:
```bash
# Deploy pod
kubectl apply -f test-pod.yaml

# Wait for pod to be ready
kubectl wait --for=condition=ready pod/kv-test-workload --timeout=60s

# Verify pod has workload identity label
kubectl get pod kv-test-workload --show-labels

# Check mounted secrets
kubectl exec kv-test-workload -- ls -la /mnt/secrets/
kubectl exec kv-test-workload -- cat /mnt/secrets/db-password
```

✅ **Success!** You should see your secret value mounted securely.

---

## **Part 5: Validation & Troubleshooting**

### **5.1 Verify Workload Identity is Working**

```bash
# Check pod events
kubectl describe pod kv-test-workload

# Check environment variables (should have Azure-specific vars)
kubectl exec kv-test-workload -- env | grep AZURE

# Check token mounted by workload identity
kubectl exec kv-test-workload -- ls -la /var/run/secrets/azure/tokens
```

### **5.2 Common Issues & Solutions**

| **Issue** | **Check** | **Solution** |
|-----------|-----------|--------------|
| Pod not starting | `kubectl describe pod` | Verify service account exists and has correct annotation |
| Secret not mounted | `kubectl logs kv-test-workload` | Check SecretProviderClass parameters |
| Access denied | Azure role assignment | Verify identity has Key Vault Secrets User role |
| Federation error | Federated credential | Verify subject matches: `system:serviceaccount:namespace:sa-name` |

### **5.3 Debug Commands**

```bash
# Check workload identity webhook logs
kubectl logs -n kube-system -l app=workload-identity-webhook

# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver

# Verify token projection
kubectl exec kv-test-workload -- cat /var/run/secrets/azure/tokens/azure-identity-token | jq .
```

---

## **Part 6: Advanced Scenarios**

### **6.1 Sync as Kubernetes Secret**

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
    useVMManagedIdentity: "false"
    clientID: "CLIENT_ID_PLACEHOLDER"
    keyvaultName: "KV_NAME_PLACEHOLDER"
    tenantId: "TENANT_ID_PLACEHOLDER"
    objects: |
      array:
        - |
          objectName: db-password
          objectType: secret
```

### **6.2 Multi-Namespace Setup**

```yaml
# service-account-prod.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kv-sa
  namespace: production
  annotations:
    azure.workload.identity/client-id: "YOUR_CLIENT_ID"
```

```bash
# Create federated credential for production namespace
az identity federated-credential create \
  --name aks-kv-prod \
  --identity-name $IDENTITY_NAME \
  --resource-group rg-aks-keyvault-workload \
  --issuer $OIDC_ISSUER \
  --subject system:serviceaccount:production:kv-sa \
  --audience api://AzureADTokenExchange
```

### **6.3 Using with Deployments**

Create `deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secrets
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: kv-sa
      containers:
      - name: app
        image: nginx:latest
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
            secretProviderClass: azure-kv-workload
```

---

## **Part 7: Security Best Practices**

### ✅ **Do's**
- Use **User-Assigned Managed Identity** for better isolation
- Enable **RBAC** for Key Vault instead of access policies
- Use **separate identities** for different applications
- Enable **secret rotation** with the CSI driver
- Use **network policies** to restrict pod communication

### ❌ **Don'ts**
- Don't share identities across namespaces/applications
- Don't use the same service account for all pods
- Don't disable workload identity webhook
- Don't store secrets in environment variables if avoidable

### 🔒 **Security Checklist**
- [ ] Key Vault firewall enabled
- [ ] Private endpoint configured for Key Vault
- [ ] RBAC used instead of access policies
- [ ] Federated credentials scoped to specific service accounts
- [ ] Regular rotation of secrets
- [ ] Audit logging enabled
- [ ] Pod identity label required (`azure.workload.identity/use: "true"`)

---

## **Part 8: Cleanup**

```bash
# Delete Kubernetes resources
kubectl delete pod kv-test-workload
kubectl delete secretproviderclass azure-kv-workload
kubectl delete serviceaccount kv-sa

# Delete federated credential
az identity federated-credential delete \
  --name aks-kv-federation \
  --identity-name $IDENTITY_NAME \
  --resource-group rg-aks-keyvault-workload

# Destroy all infrastructure
terraform destroy -auto-approve
```

---

## 📊 Comparison: Workload Identity vs. AAD Pod Identity

| **Aspect** | **Workload Identity** | **AAD Pod Identity** |
|------------|----------------------|---------------------|
| **Architecture** | OIDC federation + token exchange | IMDS interception + MIC/NMI |
| **In-cluster components** | None | MIC, NMI, CRDs |
| **Identity assignment** | Per-pod via service account | Per-pod via binding |
| **Token lifetime** | Configurable (up to 24h) | Fixed (8h) |
| **Performance** | Direct Azure AD communication | Proxy overhead |
| **Scalability limit** | None (per AKS limits) | ~200 identities per cluster |
| **Security model** | Token projection | Identity assignment |
| **Debug complexity** | Lower (standard OIDC) | Higher (custom components) |
| **Microsoft support** | ✅ GA, recommended | ❌ Maintenance mode |
| **Migration path** | N/A | Yes, with tools |

---

## 🚀 Production Considerations

### **Monitoring**
```bash
# Enable diagnostics for Key Vault
az monitor diagnostic-settings create \
  --name kv-diagnostics \
  --resource $(az keyvault show --name $KV_NAME --query id -o tsv) \
  --logs '[{"category": "AuditEvent","enabled": true}]' \
  --workspace $WORKSPACE_ID
```

### **Auto-rotation**
```hcl
# Terraform configuration for auto-rotation
key_vault_secrets_provider {
  secret_rotation_enabled = true
  secret_rotation_interval = "5m"
}
```

### **Network Security**
```hcl
# Enable private endpoint for Key Vault
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.endpoints.id

  private_service_connection {
    name                           = "kv-connection"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}
```

---

## 📚 Additional Resources

- 📖 [Azure Workload Identity Documentation](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- 🔧 [Workload Identity Migration Tool](https://github.com/Azure/azure-workload-identity/tree/main/cmd/migration)
- 🛠️ [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- 📊 [AKS Security Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)

---

## 💬 Discussion & Questions

Found this helpful? Have questions or suggestions?
🔗 [Join the Discussion on GitHub](https://github.com/Mohsinaleem123/Devops-all/discussions/1)

---

*Created by [Mohsin Aleem](https://github.com/Mohsinaleem123)* | *Last Updated: February 2025* | *Focus: Workload Identity with AKS + Key Vault*
