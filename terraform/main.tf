provider "aws" {
  region = var.aws_region
}

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
    description = "NiFi HTTP UI"
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

resource "aws_key_pair" "nifi" {
  key_name   = var.key_name
  public_key = file("${path.module}/nifi-key.pub")
}

resource "aws_instance" "nifi" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.nifi_sg.id]
  key_name               = aws_key_pair.nifi.key_name

  tags = {
    Name = "NiFi_Instance"
  }
}

output "nifi_public_ip" {
  description = "Public IP of the NiFi EC2"
  value       = aws_instance.nifi.public_ip
}