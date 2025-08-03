#!/bin/bash
public_ip=$(terraform -chdir=terraform output -raw nifi_public_ip)
echo "[nifi]" > inventory.ini
echo "$public_ip ansible_user=ubuntu ansible_ssh_private_key_file=./nifi-key.pem" >> inventory.ini
echo "Wrote inventory.ini → $public_ip"
