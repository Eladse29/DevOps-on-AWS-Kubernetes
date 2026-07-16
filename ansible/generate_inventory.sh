# Generate Ansible inventory dynamically from Terraform outputs

#!/bin/bash

cd ../

FRONTEND_PUBLIC_IP=$(terraform output -raw frontend_public_ip)
BACKEND_PUBLIC_IP=$(terraform output -raw backend_public_ip)
WORKER_PUBLIC_IP=$(terraform output -raw worker_public_ip)

BACKEND_PRIVATE_IP=$(terraform output -raw backend_private_ip)
WORKER_PRIVATE_IP=$(terraform output -raw worker_private_ip)

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
S3_BUCKET_NAME=$(terraform output -raw s3_bucket_name)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

cat > ansible/inventory.ini <<EOF
[frontend]
$FRONTEND_PUBLIC_IP

[backend]
$BACKEND_PUBLIC_IP

[worker]
$WORKER_PUBLIC_IP

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/elad2.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

backend_private_ip=$BACKEND_PRIVATE_IP
worker_private_ip=$WORKER_PRIVATE_IP

rds_endpoint=$RDS_ENDPOINT
s3_bucket_name=$S3_BUCKET_NAME
sns_topic_arn=$SNS_TOPIC_ARN
aws_region=us-east-1
db_name=devopsdb
db_user=postgres
EOF