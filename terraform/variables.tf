variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "instance_type" {
  type    = string
  default = "t2.medium"
}

variable "ami_id" {
  type    = string
  default = "ami-04f167a56786e4b09"
}

variable "key_name" {
  type    = string
  default = "nifi-key"
}

variable "s3_bucket_name" {
  description = "Bucket to hold NiFi artifacts"
  type        = string
  default     = "my-nifi-artifacts"
}
