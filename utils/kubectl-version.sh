#!/bin/bash -e

KUBECTL_DEFAULT_VERSION="${1}"

echo "Changing kubectl version to ${KUBECTL_DEFAULT_VERSION}..."
rm -f /usr/local/bin/kubectl
ln -s /usr/local/bin/kubectl-${KUBECTL_DEFAULT_VERSION} /usr/local/bin/kubectl
echo "Current version:"
kubectl version --client