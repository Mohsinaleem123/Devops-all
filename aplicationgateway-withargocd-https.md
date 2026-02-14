Deploying AKS with Application Gateway Ingress Controller (AGIC) and ArgoCD with SSL


```markdown

This guide walks through setting up an Azure Kubernetes Service (AKS) cluster, enabling the Application Gateway Ingress Controller (AGIC), deploying ArgoCD, and exposing it securely with HTTPS using Azure Application Gateway's native SSL capabilities.

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- `kubectl` installed
- Helm installed
- Proper permissions to create resources in your Azure subscription

## 1. Create Resource Group and AKS Cluster

Set environment variables for your cluster and resource group:

```bash
AKS_NAME='ARGO-cd-cluster'
RESOURCE_GROUP='argocd-RG'
LOCATION='Eastus'
VM_SIZE='Standard_D2alds_v7'   # Ensure this size is available in your location
```

Create the resource group:

```bash
az group create --name $RESOURCE_GROUP --location $LOCATION
```

Create the AKS cluster with OIDC issuer, workload identity, and Gateway API enabled. We'll also enable the Application Gateway Ingress Controller add-on later.

```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $AKS_NAME \
  --location $LOCATION \
  --node-vm-size 'D2s_v3' \
  --network-plugin azure \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-gateway-api \
  --enable-application-load-balancer \
  --generate-ssh-key
```

## 2. Create an Azure Application Gateway and Enable AGIC

### Create a Public IP, VNet, and Application Gateway

```bash
az network public-ip create \
  --name myPublicIp \
  --resource-group $RESOURCE_GROUP \
  --allocation-method Static \
  --sku Standard

az network vnet create \
  --name myVnet \
  --resource-group $RESOURCE_GROUP \
  --address-prefix 10.0.0.0/16 \
  --subnet-name mySubnet \
  --subnet-prefix 10.0.0.0/24

az network application-gateway create \
  --name myApplicationGateway \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_v2 \
  --public-ip-address myPublicIp \
  --vnet-name myVnet \
  --subnet mySubnet \
  --priority 100
```

### Enable the AGIC Add‑on

Get the Application Gateway resource ID and enable the add‑on on your AKS cluster:

```bash
appgwId=$(az network application-gateway show \
  --name myApplicationGateway \
  --resource-group $RESOURCE_GROUP \
  -o tsv --query "id")

az aks enable-addons \
  --name $AKS_NAME \
  --resource-group $RESOURCE_GROUP \
  --addon ingress-appgw \
  --appgw-id $appgwId
```

### Peer the VNets

AGIC requires connectivity between the AKS cluster and the Application Gateway. Peer the VNets:

```bash
nodeResourceGroup=$(az aks show \
  --name $AKS_NAME \
  --resource-group $RESOURCE_GROUP \
  -o tsv --query "nodeResourceGroup")

aksVnetName=$(az network vnet list \
  --resource-group $nodeResourceGroup \
  -o tsv --query "[0].name")

aksVnetId=$(az network vnet show \
  --name $aksVnetName \
  --resource-group $nodeResourceGroup \
  -o tsv --query "id")

# Peer from AppGW VNet to AKS VNet
az network vnet peering create \
  --name AppGWtoAKSVnetPeering \
  --resource-group $RESOURCE_GROUP \
  --vnet-name myVnet \
  --remote-vnet $aksVnetId \
  --allow-vnet-access

appGWVnetId=$(az network vnet show \
  --name myVnet \
  --resource-group $RESOURCE_GROUP \
  -o tsv --query "id")

# Peer from AKS VNet to AppGW VNet
az network vnet peering create \
  --name AKStoAppGWVnetPeering \
  --resource-group $nodeResourceGroup \
  --vnet-name $aksVnetName \
  --remote-vnet $appGWVnetId \
  --allow-vnet-access
```

After peering, verify that the AGIC is working by checking if an Ingress can be created (optional test):

```bash
kubectl get ingress -A
```

## 3. Install ArgoCD Using Helm

Add the Argo Helm repository and install ArgoCD in the `argocd` namespace:

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd
```

> **Note:** The default ArgoCD server runs on HTTPS with a self‑signed certificate. To simplify initial setup, you can start the server in `--insecure` mode (or we will handle SSL at the Application Gateway level). Optionally, update the deployment:

```bash
helm upgrade argocd argo/argo-cd -n argocd \
  --set server.extraArgs={--insecure}
kubectl rollout restart deployment argocd-server -n argocd
```

## 4. Expose ArgoCD via an Ingress with AGIC

Create an Ingress resource for ArgoCD. This first example uses HTTP only – we’ll add HTTPS in the next step.

Save the following YAML as `ingress-argocd.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/backend-protocol: "http"
    appgw.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

Apply the Ingress:

```bash
kubectl apply -f ingress-argocd.yaml
```

Check that the Ingress gets an IP address:

```bash
kubectl get ingress -A
```

You should see an external IP (the Application Gateway’s public IP) assigned.

## 5. Configure HTTPS with SSL/TLS

You have two main options for enabling HTTPS on the Application Gateway:

- **Option A:** Use Azure’s managed certificates (simplest, fully automated).
- **Option B:** Upload your own certificate (self‑signed or from a CA).

### Option A: Managed Certificate (Recommended)

Azure Application Gateway can automatically provision and renew a certificate for a domain you own. This avoids managing secrets in Kubernetes.

1. **In the Azure Portal**, go to your Application Gateway.
2. Under **Listeners**, click **Add**.
3. Choose **Protocol: HTTPS**, and enter your domain (e.g., `argocd.yourcompany.com`).
4. Under **Certificate**, select **Create new certificate** → **Use managed certificate**.
5. Azure will validate the domain and automatically generate and renew the certificate.

Now update your Ingress to include the hostname and reference the certificate (if needed – AGIC can automatically link the listener). A minimal Ingress that uses the host header:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    appgw.ingress.kubernetes.io/backend-protocol: "http"
spec:
  ingressClassName: azure-application-gateway
  rules:
  - host: argocd.yourcompany.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

Apply the changes:

```bash
kubectl apply -f ingress-argocd.yaml
```

AGIC will automatically wire this Ingress to the HTTPS listener you created.

### Option B: Upload Your Own Certificate (Self‑signed Example)

If you don't have a domain or want to test with a self‑signed certificate, you can upload a PFX file to the Application Gateway.

#### Generate a Self‑signed Certificate

```bash
DOMAIN="argocd.yourcompany.com"

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout $DOMAIN.key \
  -out $DOMAIN.crt \
  -subj "/CN=$DOMAIN/O=pvt"

openssl pkcs12 -export \
  -out $DOMAIN.pfx \
  -inkey $DOMAIN.key \
  -in $DOMAIN.crt \
  -passout pass:MyStrongPassword123
```

#### Upload the Certificate to Application Gateway

```bash
az network application-gateway ssl-cert create \
  --resource-group $RESOURCE_GROUP \
  --gateway-name myApplicationGateway \
  --name mySelfSignedCert \
  --cert-file $DOMAIN.pfx \
  --cert-password "MyStrongPassword123"
```

#### Reference the Certificate in the Ingress

Update your Ingress with the certificate name and enable SSL redirection:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    appgw.ingress.kubernetes.io/backend-protocol: "http"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "mySelfSignedCert"
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: azure-application-gateway
  rules:
  - host: argocd.yourcompany.com   # or your domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

Apply:

```bash
kubectl apply -f ingress-argocd.yaml
```

Now your ArgoCD should be accessible via HTTPS at `https://argocd.yourcompany.com`.

## 6. (Optional) Use Azure Key Vault for Certificate Management

If you prefer to store the certificate in Azure Key Vault and have AGIC fetch it, you can integrate Key Vault with the AKS cluster using the Secrets Store CSI driver.

Create a Key Vault and grant access to the AKS managed identity:

```bash
RG_NAME="argocd-RG"
LOCATION="CentralUS"
KV_NAME="argocd-kv-001"

az keyvault create \
  --name $KV_NAME \
  --resource-group $RG_NAME \
  --location $LOCATION \
  --sku standard
```

Find the principal ID of the identity used by the Secrets Store CSI driver (it is created by the AGIC add‑on):

```bash
az identity show \
  --name azurekeyvaultsecretsprovider-<cluster-name> \
  --resource-group MC_${RG_NAME}_${AKS_NAME}_${LOCATION} \
  --query principalId \
  --output tsv
```

Assign the **Key Vault Secrets User** role to that identity:

```bash
SP_ID="<principal-id-from-above>"
az role assignment create \
  --assignee $SP_ID \
  --role "Key Vault Secrets User" \
  --scope $(az keyvault show --name $KV_NAME --query id -o tsv)
```

You can then upload your certificate to Key Vault and configure a `SecretProviderClass` to mount it into the AGIC pod. This is an advanced scenario; refer to the [AGIC Key Vault integration documentation](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-key-vault) for details.

## 7. Verification

After applying the Ingress, you can check that the Application Gateway has the appropriate listeners and rules:

```bash
az network application-gateway ssl-cert list \
  --resource-group $RESOURCE_GROUP \
  --gateway-name myApplicationGateway \
  -o table

az network application-gateway http-listener list \
  --resource-group $RESOURCE_GROUP \
  --gateway-name myApplicationGateway \
  -o table

az network application-gateway rule list \
  --resource-group $RESOURCE_GROUP \
  --gateway-name myApplicationGateway \
  -o table
```

Finally, retrieve the initial ArgoCD admin password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD at `https://argocd.yourcompany.com` (or the IP if no domain) and log in with username `admin` and the password above.

---

## Clean Up

To avoid ongoing charges, delete the resource group when you're done:

```bash
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

## References

- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Application Gateway Ingress Controller](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview)
- [ArgoCD Helm Chart](https://artifacthub.io/packages/helm/argo/argo-cd)
- [AGIC with Key Vault](https://learn.microsoft.com/en-us/azure/application-gateway/ingress-controller-key-vault)
```
## 💬 Discussion & Questions

Found this helpful? Have questions? Join the discussion:
🔗 [GitHub Discussion](https://github.com/Mohsinaleem123/Devops-all/discussions/1)

---

*Created by [Mohsin Aleem](https://github.com/Mohsinaleem123)* | *Last Updated: February 2025*

