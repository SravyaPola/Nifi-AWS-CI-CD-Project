#!/usr/bin/env bash
set -euo pipefail

IP=$(terraform -chdir=terraform output -raw nifi_public_ip)

cat > inventory.ini <<EOF
[ec2]
$IP ansible_user=ubuntu ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ForwardAgent=yes'
EOF

echo "Wrote inventory.ini → $IP"
