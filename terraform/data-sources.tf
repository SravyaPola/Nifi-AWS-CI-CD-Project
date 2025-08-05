# Use your default VPC for both EC2 and EKS
data "aws_vpc" "default" {
  default = true
}

# All subnets in that VPC for EKS
data "aws_subnets" "default" {
   filter {
     name   = "vpc-id"
     values = [data.aws_vpc.default.id]
   }
}

# Fetch the EKS-optimized Amazon Linux 2 AMI for our k8s version
data "aws_ssm_parameter" "eks_al2_ami" {
  name = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2/recommended/image_id"
}

