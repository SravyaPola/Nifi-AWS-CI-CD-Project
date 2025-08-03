provider "aws" {
  region = var.aws_region
}

# ──────────────── VPC & Security Group ────────────────
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "nifi_sg" {
  name        = "nifi-sg"
  description = "Allow SSH & NiFi UI"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NiFi UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ──────────────── SSH Key Pair ────────────────
resource "aws_key_pair" "nifi" {
  key_name   = var.key_name
  public_key = file("${path.module}/nifi-key.pub")
}

# ──────────────── S3 Bucket for NiFi ZIP ────────────────
resource "aws_s3_bucket" "nifi_artifacts" {
  bucket = var.s3_bucket_name

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name        = "nifi-artifacts"
    Environment = "ci"
  }
}

# ──────────────── IAM Role & Profile for EC2 → S3 Read ────────────────
data "aws_iam_policy_document" "nifi_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nifi_s3_read" {
  name               = "nifi-s3-read-role"
  assume_role_policy = data.aws_iam_policy_document.nifi_assume_role.json
}

resource "aws_iam_role_policy" "nifi_s3_read_policy" {
  name = "nifi-s3-read"
  role = aws_iam_role.nifi_s3_read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "nifi_profile" {
  name = "nifi-instance-profile"
  role = aws_iam_role.nifi_s3_read.name
}

# ──────────────── NiFi EC2 Instance ────────────────
resource "aws_instance" "nifi" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.nifi_sg.id]
  key_name               = aws_key_pair.nifi.key_name
  iam_instance_profile   = aws_iam_instance_profile.nifi_profile.name

  tags = {
    Name = "NiFi_Instance"
  }
}
