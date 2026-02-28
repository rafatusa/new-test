terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
  backend "s3" {
    bucket = "devops-agent-tfstate"
    key    = "Live/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"   { default = "us-east-1" }
variable "project_name" { default = "Live" }
variable "public_key"   { type = string }

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "Live-key"
  public_key = var.public_key
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "aws_security_group" "sg" {
  name   = "Live-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [name]
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "devops-agent"
  }
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.deployer.key_name
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name      = var.project_name
    Project   = var.project_name
    ManagedBy = "devops-agent"
  }
}

output "public_ip" {
  value = aws_instance.server.public_ip
}
