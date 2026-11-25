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


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}


resource "aws_key_pair" "lab" {
  key_name   = "aws-lab"
  public_key = file("~/.ssh/aws-lab.pub")
}


resource "aws_instance" "lab" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.lab.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]
  user_data              = file("${path.module}/user_data.sh")

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "aws-lab"
  }
}


output "public_ip" {
  value = aws_instance.lab.public_ip
}