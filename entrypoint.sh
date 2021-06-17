#!/bin/bash

# SSH ENV Setup (Required for AWS CLI to use the Task Role and have access to Task Metadata)
mkdir -p ${HOME}/.ssh
env > ${HOME}/.ssh/environment

# SSH "authorized_keys" Creation/Update
echo ${AUTH_KEY_B64} | base64 -d > ${HOME}/.ssh/authorized_keys

# Clean old VS Code files
rm -rf ${HOME}/.vscode-server-insiders/.*.{log,token,pid}
rm -rf ${HOME}/.vscode-server-insiders/bin

# Route 53 Record Update (Using ifconfig.me service)
aws route53 change-resource-record-sets --hosted-zone-id ${R53_ZONE_ID} --change-batch '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"'${R53_REC_HOST}'","Type":"A","TTL":'${R53_REC_TTL}',"ResourceRecords":[{"Value":"'$(curl -s ifconfig.me)'"}]}}]}' > /dev/null

# S3 EFS Backup - EFS -> Bucket
aws s3 sync ${HOME}/ s3://${S3_EFS_BACKUP}/

# Start SSH Daemon
/usr/sbin/sshd -De