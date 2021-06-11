#!/bin/bash -e

CONFIG_FILE=${HOME}/.podman-build-config
SLEEP_AFTER_DEPLOY=30

if [ ! -f ${CONFIG_FILE} ]; then
  echo "Configuration file ${CONFIG_FILE}. Aborting..."
  exit 1
fi

source ${CONFIG_FILE}

PROJECT="${1}"

if [ "${PROJECT}" == "" ]; then
  echo "Missing parameter. Aborting..."
  exit 1
elif [ "${PROJECT}" == "podman-stop" ]; then
  echo "Parameter set to podman-stop. Terminating the CoreOS instance..."
  aws cloudformation delete-stack --stack-name ${STACK_NAME}
  exit 0
fi

# Deploy Instance
AMI=$(aws ec2 describe-images --region ${AWS_REGION} --filters "Name=name,Values=fedora-coreos-${FEDORA_COREOS_VERSION}" --query "Images[0].ImageId" --output text)
aws cloudformation deploy --stack-name ${STACK_NAME} --template-file ${TEMPLATE_PATH} --parameter-overrides "AMI=${AMI}"

sleep ${SLEEP_AFTER_DEPLOY}

# Initial Instance and Podman Remote Configuration
scp ${PODMAN_KEY}.pub core@${COREOS_ADDRESS}:.ssh/authorized_keys.d/podman
ssh core@${COREOS_ADDRESS} -- systemctl enable --user --now podman.socket
podman-remote system connection add coreos --identity ${PODMAN_KEY} ssh://core@${COREOS_ADDRESS}/run/user/1000/podman/podman.sock
podman-remote info

if [ "${PROJECT}" == "podman-start" ]; then
  echo "Parameter set to podman-start. Keeping CoreOS instance up. Terminate it by running this command again with the parameter podman-stop."
  exit 0
fi

# Podman Remote Build and Private ECR Push
podman-remote build ${PROJECTS_PATH}/${PROJECT}/ -t ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest
echo "Uploading image to Private ECR ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}..."
aws ecr get-login-password | podman-remote login --username AWS --password-stdin ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
podman-remote push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest

# Public ECR Push
if [ -f ${PROJECTS_PATH}/${PROJECT}/.public-ecr ]; then
  PUBLIC_REPO=$(cat ${PROJECTS_PATH}/${PROJECT}/.public-ecr)
  echo "Uploading image to Public ECR ${PUBLIC_REPO}..."
  podman-remote tag ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT}:latest ${PUBLIC_REPO}:latest
  aws ecr-public get-login-password --region us-east-1 | podman-remote login --username AWS --password-stdin public.ecr.aws
  podman-remote push ${PUBLIC_REPO}:latest
fi

# Delete Instance
echo "Deleting the CloudFormation Stack..."
aws cloudformation delete-stack --stack-name ${STACK_NAME}
echo "Done!"