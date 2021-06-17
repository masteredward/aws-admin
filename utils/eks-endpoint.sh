#!/bin/bash

EKS_CLUSTER="${1}"
EKS_REGION="${2}"

aws eks update-cluster-config --name ${EKS_CLUSTER} --region ${EKS_REGION} --resources-vpc-config endpointPrivateAccess=true,endpointPublicAccess=true,publicAccessCidrs=$(curl -s ifconfig.me)/32 --no-cli-pager