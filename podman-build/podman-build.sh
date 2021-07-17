#!/bin/bash

CONFIG_FILE=${HOME}/.podman-build-config
source ${CONFIG_FILE}

PROJECT=${1}
STACK_NAME=${STACK_PREFIX}-$(date +%s)

discover_task_infra(){
  ALLOWED_CIDR=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r ".Containers[0].Networks[0].IPv4Addresses[0]")"/32"
  SUBNET_CIDR=$(curl -s ${ECS_CONTAINER_METADATA_URI_V4}/task | jq -r ".Containers[0].Networks[0].IPv4SubnetCIDRBlock")
  SUBNET_ID=$(aws ec2 describe-subnets --query "Subnets[?CidrBlock=='${SUBNET_CIDR}'].SubnetId" --output text)
  VPC_ID=$(aws ec2 describe-subnets --query "Subnets[?CidrBlock=='${SUBNET_CIDR}'].VpcId" --output text)
}

instance_deploy(){
  AMI=$(aws ec2 describe-images --region ${AWS_REGION} --filters "Name=name,Values=fedora-coreos-*" --query 'reverse(sort_by(Images,&CreationDate))[:1].{id:ImageId}' --output text)
  aws cloudformation deploy --stack-name ${STACK_NAME} --template-file ${TEMPLATE_PATH} --parameter-overrides "VpcId=${VPC_ID}" "SubnetId=${SUBNET_ID}" "AllowedCidr=${ALLOWED_CIDR}" "InstanceType=${INSTANCE_TYPE}" "InstanceVolumeSize=${INSTANCE_VOLUME_SIZE}" "AMI=${AMI}" "SshPubkeyName=${SSH_PUBKEY_NAME}"
  sleep 5
  COREOS_ADDRESS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].Outputs[0].OutputValue' --output text)
}

instance_delete(){
  echo "Deleting the CloudFormation Stack and Podman connection..."
  podman-remote system connection remove ${STACK_NAME}
  aws cloudformation delete-stack --stack-name ${STACK_NAME}
}

podman_connect(){
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 core@${COREOS_ADDRESS} -- exit 0
  while [ $? -ne 0 ]; do
    sleep 1
    echo "No SSH connection yet. Retrying..."
    ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 core@${COREOS_ADDRESS} -- exit 0
  done
  scp -q -o BatchMode=yes -o StrictHostKeyChecking=no ${PODMAN_KEY}.pub core@${COREOS_ADDRESS}:.ssh/authorized_keys.d/podman
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no core@${COREOS_ADDRESS} -- systemctl enable --user --now podman.socket
  podman-remote system connection add ${STACK_NAME} --identity ${PODMAN_KEY} ssh://core@${COREOS_ADDRESS}/run/user/1000/podman/podman.sock
  podman-remote -c ${STACK_NAME} info
}

podman_build(){
  if [ "${PROJECT}" == "" ]; then
    echo "Missing project name. Skipping..."
  else
    podman-remote -c ${STACK_NAME} build ${PROJECTS_PATH}/${PROJECT}/ -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest
    echo "Uploading image to Private ECR ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}..."
    aws ecr get-login-password | podman-remote -c ${STACK_NAME} login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
    podman-remote -c ${STACK_NAME} push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest
    # Optional Public ECR Push (Needs .public-ecr file with the public ECR link in the project's path)
    if [ -f ${PROJECTS_PATH}/${PROJECT}/.public-ecr ]; then
      PUBLIC_REPO=$(cat ${PROJECTS_PATH}/${PROJECT}/.public-ecr)
      echo "Uploading image to Public ECR ${PUBLIC_REPO}..."
      podman-remote -c ${STACK_NAME} tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest ${PUBLIC_REPO}:latest
      aws ecr-public get-login-password --region us-east-1 | podman-remote -c ${STACK_NAME} login --username AWS --password-stdin public.ecr.aws
      podman-remote -c ${STACK_NAME} push ${PUBLIC_REPO}:latest
    fi
  fi
}

discover_task_infra
instance_deploy
podman_connect
podman_build
instance_delete