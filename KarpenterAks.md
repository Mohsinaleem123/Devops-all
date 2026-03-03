# Deploying Karpenter on AKS with Workload Identity: Step-by-Step Guide

[Karpenter](https://karpenter.sh/) is an open-source, high-performance Kubernetes cluster autoscaler that launches right-sized compute resources in response to changing workload needs. This guide will walk you through deploying Karpenter on Azure Kubernetes Service (AKS) using **Azure AD Workload Identity** for secure, pod-level authentication to Azure APIs.

> **⚠️ Important**  
> The Azure provider for Karpenter is currently in **alpha** stage and under active development. It is not yet recommended for production use. This guide is for evaluation and testing purposes only.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Understanding Workload Identity](#understanding-workload-identity)
- [Step 1: Create an AKS Cluster with OIDC Issuer and Workload Identity](#step-1-create-an-aks-cluster-with-oidc-issuer-and-workload-identity)
- [Step 2: Install cert-manager](#step-2-install-cert-manager)
- [Step 3: Prepare Azure Resources for Karpenter](#step-3-prepare-azure-resources-for-karpenter)
- [Step 4: Create a User-Assigned Managed Identity and Grant Permissions](#step-4-create-a-user-assigned-managed-identity-and-grant-permissions)
- [Step 5: Establish Federated Identity Credential](#step-5-establish-federated-identity-credential)
- [Step 6: Install Karpenter with Workload Identity](#step-6-install-karpenter-with-workload-identity)
- [Step 7: Create a Provisioner](#step-7-create-a-provisioner)
- [Step 8: Deploy a Demo Workload](#step-8-deploy-a-demo-workload)
- [Step 9: Clean Up](#step-9-clean-up)
- [Conclusion](#conclusion)

---

## Prerequisites

- An **Azure subscription** (with Contributor permissions)
- **Azure CLI** installed and logged in (`az login`)
- **kubectl** installed
- **Helm 3** installed
- Basic knowledge of Kubernetes and Azure concepts

---

## Understanding Workload Identity

[Azure AD Workload Identity](https://azure.github.io/azure-workload-identity/docs/) is the recommended way for pods running in AKS to authenticate to Azure services. It uses federated identity credentials to allow a Kubernetes service account to exchange its Kubernetes-issued token for an Azure AD token. This approach is more secure than using service principal secrets or relying on the node's managed identity because permissions are scoped per pod/service account.

Karpenter will use a Kubernetes service account that is annotated with `azure.workload.identity/client-id`. The Azure AD token will be automatically mounted into the pod (via the workload identity webhook) and used by the Karpenter Azure provider to manage VM resources.

---

## Step 1: Create an AKS Cluster with OIDC Issuer and Workload Identity

We need an AKS cluster with an OIDC issuer and workload identity enabled.

```bash
# Set variables
export RESOURCE_GROUP="karpenter-demo-rg"
export CLUSTER_NAME="karpenter-demo"
export LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster with OIDC issuer and workload identity
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 1 \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

After creation, retrieve the OIDC issuer URL:

```bash
export AKS_OIDC_ISSUER=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "oidcIssuerProfile.issuerUrl" -o tsv)
echo $AKS_OIDC_ISSUER
```

---

## Step 2: Install cert-manager

Karpenter uses a webhook that requires cert-manager to provision certificates.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

# Wait for cert-manager pods to be ready
kubectl wait --for=condition=Ready pod -l app=cert-manager -n cert-manager --timeout=120s
```

---

## Step 3: Prepare Azure Resources for Karpenter

Karpenter will create VMs in a specific subnet. We need to create a virtual network, subnet, and network security group (or use existing ones).

```bash
# Create VNet and subnet (if you don't have existing)
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name karpenter-demo-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name default \
  --subnet-prefix 10.0.0.0/24

# Get subnet ID
export SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name karpenter-demo-vnet --name default --query id -o tsv)

# Create a network security group (optional but recommended)
az network nsg create \
  --resource-group $RESOURCE_GROUP \
  --name karpenter-demo-nsg

export NSG_ID=$(az network nsg show --resource-group $RESOURCE_GROUP --name karpenter-demo-nsg --query id -o tsv)
```

---

## Step 4: Create a User-Assigned Managed Identity and Grant Permissions

Create a user-assigned managed identity that Karpenter will use to manage Azure resources.

```bash
export IDENTITY_NAME="karpenter-identity"

az identity create \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY_NAME

export IDENTITY_CLIENT_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query clientId -o tsv)
export IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query principalId -o tsv)
export IDENTITY_RESOURCE_ID=$(az identity show --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME --query id -o tsv)
```

### Assign Required RBAC Roles to the Identity

Karpenter needs at least:
- **Virtual Machine Contributor** on the resource group (or a specific scope)
- **Network Contributor** on the virtual network (or subnet)

```bash
# Get subscription ID
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Assign Virtual Machine Contributor on the resource group
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "Virtual Machine Contributor" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP

# Assign Network Contributor on the virtual network (or subnet)
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "Network Contributor" \
  --scope $SUBNET_ID
```

---

## Step 5: Establish Federated Identity Credential

Now we create a federated identity credential that links the managed identity to the Kubernetes service account that Karpenter will use. We'll use the namespace `karpenter` and service account name `karpenter` (the default name used by the Helm chart).

```bash
# Create the credential
az identity federated-credential create \
  --name "karpenter-federated-credential" \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:karpenter:karpenter \
  --audience api://AzureADTokenExchange
```

> **Explanation**:  
> - `--subject` must match the Kubernetes service account's fully qualified name: `system:serviceaccount:<namespace>:<serviceaccount>`.  
> - `--audience` is fixed to `api://AzureADTokenExchange` (the default audience used by the workload identity webhook).  

---

## Step 6: Install Karpenter with Workload Identity

Add the Karpenter Helm repository and prepare values.

```bash
helm repo add karpenter https://charts.karpenter.sh
helm repo update
```

Create a namespace for Karpenter:

```bash
kubectl create namespace karpenter
```

We'll install Karpenter with custom values to enable Azure provider and workload identity.

Create a `values.yaml` file:

```yaml
serviceAccount:
  create: true
  name: karpenter
  annotations:
    azure.workload.identity/client-id: ${IDENTITY_CLIENT_ID}

# Disable AWS-specific settings
aws:
  defaultInstanceProfile: ""
  clusterName: ""
  clusterEndpoint: ""
  interruptionQueueName: ""

# Enable Azure provider
azure:
  enabled: true

controller:
  env:
    - name: AZURE_CLIENT_ID
      value: ${IDENTITY_CLIENT_ID}
    - name: AZURE_SUBSCRIPTION_ID
      value: ${SUBSCRIPTION_ID}
    - name: AZURE_RESOURCE_GROUP
      value: ${RESOURCE_GROUP}
    - name: AZURE_LOCATION
      value: ${LOCATION}
    - name: AZURE_CLUSTER_NAME
      value: ${CLUSTER_NAME}
    - name: ARM_USE_MSI
      value: "true"
```

> **Note**: The exact environment variables may evolve. Refer to the [karpenter-provider-azure](https://github.com/Azure/karpenter-provider-azure) documentation for the latest.

Apply the Helm installation, substituting variables:

```bash
helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$IDENTITY_CLIENT_ID \
  --set aws.defaultInstanceProfile="" \
  --set aws.clusterName="" \
  --set aws.clusterEndpoint="" \
  --set aws.interruptionQueueName="" \
  --set controller.env[0].name=AZURE_CLIENT_ID \
  --set controller.env[0].value=$IDENTITY_CLIENT_ID \
  --set controller.env[1].name=AZURE_SUBSCRIPTION_ID \
  --set controller.env[1].value=$SUBSCRIPTION_ID \
  --set controller.env[2].name=AZURE_RESOURCE_GROUP \
  --set controller.env[2].value=$RESOURCE_GROUP \
  --set controller.env[3].name=AZURE_LOCATION \
  --set controller.env[3].value=$LOCATION \
  --set controller.env[4].name=AZURE_CLUSTER_NAME \
  --set controller.env[4].value=$CLUSTER_NAME \
  --set controller.env[5].name=ARM_USE_MSI \
  --set controller.env[5].value="true"
```

After installation, verify that the Karpenter pod is running and the service account has the expected annotation:

```bash
kubectl get pods -n karpenter
kubectl describe sa karpenter -n karpenter
```

You should see the annotation `azure.workload.identity/client-id` with the client ID.

---

## Step 7: Create a Provisioner

A Provisioner is a Karpenter custom resource that defines how nodes should be provisioned (instance types, zones, etc.). Create a file `provisioner.yaml`:

```yaml
apiVersion: karpenter.sh/v1beta1
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64"]
    - key: karpenter.azure.com/sku-family
      operator: In
      values: ["D", "E", "F"]
  limits:
    resources:
      cpu: 100
  providerRef:
    name: azure-provider
---
apiVersion: karpenter.azure.com/v1alpha1
kind: AzureProvider
metadata:
  name: azure-provider
spec:
  location: ${LOCATION}
  resourceGroup: ${RESOURCE_GROUP}
  subnetId: ${SUBNET_ID}
  securityGroupId: ${NSG_ID}
  vmSizeSelector:
    - name: Standard_D2s_v3
      cpu: 2
      memory: 8
      family: D
  spotMaxPrice: -1
```

> **Note**: The exact `AzureProvider` spec is evolving. Check the [latest examples](https://github.com/Azure/karpenter-provider-azure/tree/main/examples) for the correct API.

Apply the provisioner (substitute variables if needed):

```bash
envsubst < provisioner.yaml | kubectl apply -f -
```

---

## Step 8: Deploy a Demo Workload

Now we'll deploy a simple application that requests more resources than the existing node can provide, forcing Karpenter to provision a new node.

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 5
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
      - name: inflate
        image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
        resources:
          requests:
            cpu: 1
            memory: 1.5Gi
```

Apply the deployment:

```bash
kubectl apply -f deployment.yaml
```

### Watch Karpenter in Action

In one terminal, watch the pods:

```bash
kubectl get pods -w
```

In another terminal, watch Karpenter logs:

```bash
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

You should see Karpenter detect pending pods and provision a new VM in Azure. Once the node joins the cluster, the pods will be scheduled.

To verify the new node:

```bash
kubectl get nodes
```

---

## Step 9: Clean Up

To avoid incurring costs, delete the demo resources and the AKS cluster.

```bash
# Delete the deployment
kubectl delete deployment inflate

# Delete Karpenter
helm uninstall karpenter -n karpenter

# Delete the provisioner and AzureProvider
kubectl delete provisioner default
kubectl delete azureprovider azure-provider

# Delete the federated identity credential
az identity federated-credential delete \
  --name "karpenter-federated-credential" \
  --identity-name $IDENTITY_NAME \
  --resource-group $RESOURCE_GROUP

# Delete the managed identity
az identity delete --resource-group $RESOURCE_GROUP --name $IDENTITY_NAME

# Delete the AKS cluster and resource group
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

---

## Conclusion

You've successfully deployed Karpenter on AKS using Azure AD Workload Identity for secure authentication. This approach ensures that Karpenter pods have the minimum necessary permissions to manage Azure resources, following security best practices.

While the Azure provider is still in alpha, this setup demonstrates the power of Karpenter's flexible, fast autoscaling combined with Azure's identity management.

For more details, check out:

- [Karpenter Azure Provider GitHub Repository](https://github.com/Azure/karpenter-provider-azure)
- [Azure AD Workload Identity Documentation](https://azure.github.io/azure-workload-identity/)
- [Karpenter Documentation](https://karpenter.sh/)

Happy scaling!
