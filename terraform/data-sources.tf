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

# Pull in the Ubuntu EKS-optimized AMI for your k8s version
data "aws_ssm_parameter" "ubuntu_eks_ami" {
  name = "/aws/service/canonical/ubuntu/eks/${var.cluster_version}/stable/2024-07-01/amd64/hvm/ebs-gp2/ami-id"
}
