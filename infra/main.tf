terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.23"
    }
  }
}


provider "aws" {
  region = "ap-southeast-1"

  default_tags {
    tags = {
      Project   = "tinyshop"
      ManagedBy = "terraform"
    }
  }
}

variable "my_ip" {
  description = "My public in CIDR form, e.g. 1.2.3.4/32"
  type        = string
}

resource "aws_security_group" "ssh" {
  name        = "aws-lab-ssh"
  description = "SSH from my IP only"
}


resource "aws_vpc_security_group_ingress_rule" "ssh_from_me" {
  security_group_id = aws_security_group.ssh.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.my_ip
}
resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.ssh.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}