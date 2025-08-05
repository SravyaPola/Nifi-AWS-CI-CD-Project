output "nifi_public_ip" {
  value = aws_instance.nifi.public_ip
}
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_ca_data" {
  description = "Cluster CA cert data"
  value       = aws_eks_cluster.eks.certificate_authority[0].data
}

output "subnet_ids" {
  description = "Subnet IDs used by EKS"
  value       = data.aws_subnets.default.ids
}

output "vpc_id" {
  description = "VPC ID in use"
  value       = data.aws_vpc.default.id
}