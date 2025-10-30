# output "alb_dns_name" {
#   description = "DNS name of the Application Load Balancer"
#   value       = aws_lb.main.dns_name
# }

# output "alb_url" {
#   description = "URL to access the web application"
#   value       = "http://${aws_lb.main.dns_name}"
# }

output "instance_public_ips" {
  description = "Public IP addresses of running instances"
  value       = data.aws_instances.web_servers.public_ips
}

output "instance_public_urls" {
  description = "Public URLs to access the web application (for DAST scanning)"
  value       = [for ip in data.aws_instances.web_servers.public_ips : "http://${ip}"]
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}
