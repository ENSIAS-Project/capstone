# ALB Migration Guide

## Current Setup (Without ALB)

The infrastructure is currently deployed **WITHOUT** an Application Load Balancer due to AWS Academy account restrictions. Instances are deployed in **public subnets** with **public IP addresses** for direct HTTP access.

### Current Architecture:
- EC2 instances in **public subnets** (public_1, public_2)
- Instances have **public IPs** assigned
- Security group allows HTTP (port 80) from **anywhere** (0.0.0.0/0)
- Auto Scaling Group manages instances
- Access via: **Instance Public DNS or Public IP**

---

## How to Add ALB Later (When AWS Account Allows)

When your AWS account is fully activated and allows ALB creation, follow these steps:

### Step 1: Uncomment ALB Resources in `main.tf`

Find the section marked:
```hcl
# ============================================
# ALB RESOURCES - COMMENTED OUT FOR NOW
# Uncomment when AWS account allows ALB creation
# ============================================
```

**Uncomment these three resources:**
1. `aws_lb.main` (Application Load Balancer)
2. `aws_lb_target_group.main` (Target Group)
3. `aws_lb_listener.main` (ALB Listener)

### Step 2: Modify Auto Scaling Group

In the `aws_autoscaling_group.web` resource:

**Change FROM (current):**
```hcl
resource "aws_autoscaling_group" "web" {
  name                      = "capstone-asg"
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  # target_group_arns         = [aws_lb_target_group.main.arn]  # Commented out
  health_check_type         = "EC2"
  health_check_grace_period = 400
  min_size                  = 1
  max_size                  = var.asg_max_size
  desired_capacity          = 1
  # ...
}
```

**Change TO:**
```hcl
resource "aws_autoscaling_group" "web" {
  name                      = "capstone-asg"
  vpc_zone_identifier       = [aws_subnet.private_1.id, aws_subnet.private_2.id]  # Move to PRIVATE subnets
  target_group_arns         = [aws_lb_target_group.main.arn]  # Uncomment this
  health_check_type         = "ELB"  # Change to ELB
  health_check_grace_period = 400
  min_size                  = 2  # Increase back to 2
  max_size                  = var.asg_max_size
  desired_capacity          = 2  # Increase back to 2
  # ...
}
```

### Step 3: Update Security Group

In the `aws_security_group.web` resource:

**Change FROM (current):**
```hcl
resource "aws_security_group" "web" {
  # ...
  # Allow HTTP from anywhere (since no ALB)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }
  # ...
}
```

**Change TO:**
```hcl
resource "aws_security_group" "web" {
  # ...
  # Allow HTTP from ALB only
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTP from ALB"
  }
  # ...
}
```

### Step 4: Update Launch Template

In the `aws_launch_template.web` resource:

**Remove the network_interfaces block** (or set `associate_public_ip_address = false`):

```hcl
resource "aws_launch_template" "web" {
  # ...
  # Remove or modify this:
  # network_interfaces {
  #   associate_public_ip_address = true
  #   device_index                = 0
  #   security_groups             = [aws_security_group.web.id]
  # }

  # Instances in private subnets don't need public IPs
  # ...
}
```

### Step 5: Update Outputs in `outputs.tf`

**Uncomment the ALB outputs:**
```hcl
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "URL to access the web application"
  value       = "http://${aws_lb.main.dns_name}"
}
```

**Remove or comment out:**
```hcl
# output "instance_access_info" {
#   description = "Instructions to access instances directly"
#   value       = "Run: aws ec2 describe-instances..."
# }
```

### Step 6: Apply Changes

```bash
# Plan the changes
terraform plan

# Apply the changes
terraform apply

# Get the ALB DNS name
terraform output alb_url
```

### Step 7: Update DNS (if using custom domain)

If you're using a custom domain with Route 53:
- Update your DNS record to point to the ALB DNS name
- Use an ALIAS record type for best performance

---

## Summary of Changes

| Component | Current (No ALB) | With ALB |
|-----------|------------------|----------|
| **EC2 Location** | Public subnets | Private subnets |
| **Public IPs** | Yes | No |
| **Security Group** | Allow from 0.0.0.0/0 | Allow from ALB SG only |
| **Health Check** | EC2 | ELB |
| **Access Method** | Instance Public DNS | ALB DNS |
| **Instance Count** | 1 (min/desired) | 2 (min/desired) |

---

## Benefits of Adding ALB

1. **Security**: Instances in private subnets, not directly exposed
2. **High Availability**: Traffic distributed across multiple AZs
3. **SSL/TLS Termination**: Can add HTTPS at ALB level
4. **Health Checks**: Automatic instance health monitoring
5. **Auto Scaling**: Better integration with ASG for scaling
6. **Single DNS**: One endpoint for all instances
7. **Path-based Routing**: Can route different paths to different targets

---

## Testing After Migration

1. **Verify ALB is healthy:**
   ```bash
   aws elbv2 describe-load-balancers --names capstone-alb
   ```

2. **Check target health:**
   ```bash
   aws elbv2 describe-target-health --target-group-arn <TARGET-GROUP-ARN>
   ```

3. **Test the application:**
   ```bash
   curl http://<ALB-DNS-NAME>/health.txt
   curl http://<ALB-DNS-NAME>/
   ```

4. **Verify instances are not directly accessible** (should timeout):
   ```bash
   curl http://<INSTANCE-PRIVATE-IP>/
   ```

---

## Rollback Plan

If something goes wrong during migration:

```bash
# Revert to previous state
terraform apply -target=aws_autoscaling_group.web -var="asg_min_size=1"

# Or restore from backup
cp main.tf.backup main.tf
terraform apply
```

Always keep a backup of your working configuration before making changes!
