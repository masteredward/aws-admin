# utils

These are the utility scripts bundled with the **aws-admin** container:

## eks-endpoint

This script updates an **EKS Cluster** *Public Endpoint ACL*, authorizing *only* the public IP of the **aws-admin** task to reach it.

## podman-build

This script provision a **Fedora CoreOS** EC2 instance to *build* container images using **podman** and **podman-remote**.

Usage:
- TBA

## kubectl-version

This script is a helper to change the default **kubectl** version. Since the **aws-admin** image bundles *all* the **kubectl** versions for currently supported **EKS** clusters, this script creates a symbolic link in `/usr/local/kubectl` to the choosen kubectl version. Example:
```
kubectl-version 1.20
```