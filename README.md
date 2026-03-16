# g4e-dggs JupyterHub on OVHCloud

JupyterHub deployment on OVHCloud Kubernetes (MKS) using OpenTofu.

## Stack

- JupyterHub 4.3.2 (Zero-to-JupyterHub)
- Dask Gateway 2025.4.0
- Pangeo notebook image (pangeo/pangeo-notebook:2025.05.22)
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

## Notes on version pinning

The notebook image and the Dask Gateway backend image must share the same Python environment to avoid serialization errors at runtime. Both are pinned to `pangeo/pangeo-notebook:2025.05.22` (`distributed==2025.2.0`), which is compatible with the Dask Gateway 2025.4.0 scheduler (`distributed==2025.3.0`).

If you upgrade the notebook image, make sure to update `dask-gateway-values.yaml` accordingly and test with a simple `dask.array` computation before deploying to users.

The `gateway.prefix` in `dask-gateway-values.yaml` must be set to `/services/dask-gateway` to match the JupyterHub proxy routing. Setting it to `/` causes 404 errors on all API calls.
