# Use your default VPC for both EC2 and EKS
data "aws_vpc" "default" {
  default = true
}

# All subnets in that VPC for EKS
data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
