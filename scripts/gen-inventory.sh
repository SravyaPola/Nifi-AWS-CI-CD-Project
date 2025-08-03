#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"

IP=$(terraform output -raw nifi_public_ip)

cat > ../inventory.ini <<EOF
[ec2]
${IP} ansible_host=${IP} ansible_user=ubuntu \
      ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "Wrote inventory.ini → ${IP}"
