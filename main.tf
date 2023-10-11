provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"
  name = "poc-vpc"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = false
  single_nat_gateway   = false
  enable_dns_hostnames = true
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
    Name = "lamp"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.202*-x86_64-ebs"]
  }
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
  ami                    = data.aws_ami.amazon_linux.id
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
resource "null_resource" "toec2" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "remote-exec" {
    inline = ["echo Connected!"]
    connection {
      host        = module.ec2_public.public_ip
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.ec2_instance.private_key_openssh}"
    }
  }
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      SOME_VAR = "VALUE"
    }
    command = <<-EOL
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ec2-user -i '${module.ec2_public.public_ip},' --private-key ./${var.generated_key_name}.pem ansible/install.yml
      rm -rfv ./${var.generated_key_name}.pem
    EOL
  }
}