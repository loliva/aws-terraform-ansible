provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.77.0"
  name                 = "${var.vpc_name}-${var.env}"   # variable concatenada
  cidr                 = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = var.vpc_public_subnets
  private_subnets      = var.vpc_private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  one_nat_gateway_per_az = false
  enable_dns_support   = true
}

resource "aws_security_group" "sg_ec2" {
  name   = "SG_EC2"
  vpc_id = module.vpc.vpc_id
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

  tags = {
    Name = "instance-ec2"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}


resource "tls_private_key" "ec2_instance" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "null_resource" "generate_key" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<-EOL
      echo '${tls_private_key.ec2_instance.private_key_pem}' > ./${var.generated_key_name}.pem
      chmod 400 ./${var.generated_key_name}.pem
      EOL
    }
  }

resource "aws_key_pair" "generated_key" {
  key_name   = var.ec2_key_name
  public_key = tls_private_key.ec2_instance.public_key_openssh
}

module "ec2_public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  create  = var.ec2_instance_create
  name = var.ec2_instance_name
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  monitoring             = false
  vpc_security_group_ids = [aws_security_group.sg_ec2.id]
  subnet_id              = module.vpc.public_subnets[0]
  ## User data for machine
  //user_data              = <<-EOL
  //#!/bin/bash -xe
  //apt install postgresql-client-12 python3-psycopg2 python3 -y
  //EOL
}
module "ec2_private" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  for_each = toset(["one", "two"])
  create  = var.ec2_instance_create
  name = "private-instance-${each.key}"
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.generated_key.key_name
  monitoring             = false
  vpc_security_group_ids = [aws_security_group.sg_ec2.id]
  subnet_id              = module.vpc.private_subnets[0]
}

resource "null_resource" "toec2" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "remote-exec" {
    inline = ["echo Connected!"]
    connection {
      host        = module.ec2_public.public_ip
      type        = "ssh"
      user        = "ubuntu"
      private_key = "${tls_private_key.ec2_instance.private_key_openssh}"
    }
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SOME_VAR = "VALUE"
    }
    command = <<-EOL
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${module.ec2_public.public_ip},' --private-key ./${var.generated_key_name}.pem ansible/install.yml
      rm -rfv ./${var.generated_key_name}.pem
    EOL
  }
}
