#!/usr/bin/env bash
IP=$(terraform -chdir=terraform output -raw nifi_public_ip)
cat > inventory.ini <<INI
[ec2]
${IP} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ubuntu/.ssh/nifi-key
INI
echo "Wrote inventory.ini → ${IP}"