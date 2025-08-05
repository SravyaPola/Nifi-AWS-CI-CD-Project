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