output "private_key_openssh" {
  value       = tls_private_key.ec2_instance.private_key_openssh
  sensitive   = true
}
output "public_dns" {
    value = module.ec2_public.public_dns
}