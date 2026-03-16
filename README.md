# g4e-dggs JupyterHub on OVHCloud

JupyterHub deployment on OVHCloud Kubernetes (MKS) using OpenTofu.

## Stack
- JupyterHub 4.3.2 (Zero-to-JupyterHub)
- Dask Gateway 2025.4.0
- Pangeo notebook image (pangeo/pangeo-notebook:2026.01.30)
- GitHub OAuth authentication
- HTTPS via cert-manager + Let's Encrypt
- OVHCloud MKS (Managed Kubernetes)
- State stored in OVH S3 bucket

## Prerequisites
- OpenTofu >= 1.6
- kubectl
- helm
- git-crypt
- OVH API credentials

## Usage
```bash
# Unlock secrets
git-crypt unlock /path/to/key

# Load OVH credentials
source secrets/ovh-creds.sh

# Deploy
cd tf
tofu init
tofu apply -var-file=secrets/terraform.tfvars
```

## Known issues
- Dask Gateway TCP routing via Traefik has issues with Kubernetes 1.34 — under investigation
