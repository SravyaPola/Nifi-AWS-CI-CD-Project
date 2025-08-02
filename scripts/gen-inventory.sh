#!/usr/bin/env bash
set -euo pipefail

IP=$(terraform -chdir=terraform output -raw nifi_public_ip)

if [[ -z "$IP" ]]; then
  echo "ERROR: Could not read nifi_public_ip from Terraform"
  exit 1
fi

cat > inventory.ini <<INI
[ec2]
${IP} ansible_user=ubuntu \
ansible_ssh_private_key_file=/home/ubuntu/.ssh/nifi-key \
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
INI

echo "Wrote inventory.ini → ${IP}"
