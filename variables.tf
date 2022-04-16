variable "env" {}
variable "region" {}
variable "vpc_name" {}
variable "vpc_cidr" {}
variable "vpc_public_subnets" {}
variable "vpc_private_subnets" {}
variable "ec2_key_name" {}
variable "ec2_instance_name" {}
variable "ec2_instance_type" {}
variable "ec2_instance_create" {
  default = false
}
variable "generated_key_name" {
  default = "private-key"
}
