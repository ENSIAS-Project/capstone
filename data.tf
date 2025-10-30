# Data source to get available Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source to get the latest Amazon Linux 2 AMI
# Using AL2 instead of AL2023 because AL2 has yum and better package compatibility
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source to get running web server instances for outputs
data "aws_instances" "web_servers" {
  filter {
    name   = "tag:Name"
    values = ["capstone-web-server"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_autoscaling_group.web]
}
