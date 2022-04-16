output "id_private_subnets" {
  value       = module.vpc.private_subnets
}

output "id_public_subnets" {
  value       = module.vpc.public_subnets
}

output "id_security_group" {
  value       = module.vpc.default_security_group_id
}

output "ubuntu_ami_id" {
  value       = data.aws_ami.ubuntu.id
}

output "ec2_instance_public_ip" {
  value       = module.ec2_public.public_ip
}

output "private_key_openssh" {
  value       = tls_private_key.ec2_instance.private_key_openssh
  sensitive   = true
}
