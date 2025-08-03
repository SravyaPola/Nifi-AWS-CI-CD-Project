#!/usr/bin/env bash
set -euo pipefail

# grab the IP that Terraform just put in outputs
IP=$(terraform -chdir=terraform output -raw nifi_public_ip)

# write a clean inventory
cat > inventory.ini <<EOF
[ec2]
$IP ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "Wrote inventory.ini → $IP"
