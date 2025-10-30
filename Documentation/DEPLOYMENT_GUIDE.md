# AWS Capstone Project - Complete Deployment Guide
## Terraform Infrastructure as Code

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start Deployment](#quick-start-deployment)
5. [Database Import](#database-import)
6. [Testing & Verification](#testing--verification)
7. [Load Balancer Setup (Optional)](#load-balancer-setup-optional)
8. [Cost Management](#cost-management)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

---

## Project Overview

This Terraform configuration deploys a highly available, secure web application infrastructure on AWS, replicating the AWS Academy Cloud Architecting Capstone Project. It automates the deployment of a complete social research data platform with the **actual PHP application from the AWS Academy lab**.

### What's Deployed

- ✅ **VPC with Multi-AZ Subnets** - 2 public subnets across 2 availability zones
- ✅ **Auto Scaling Group** - 2 EC2 instances with automatic health checks
- ✅ **RDS MySQL Database** - Multi-AZ capable database for country data
- ✅ **NAT Gateway** - Secure internet access for instances
- ✅ **AWS Secrets Manager** - Secure password storage
- ✅ **S3 Integration** - PHP application files served from S3
- ✅ **Security Groups** - Port 22 (SSH), Port 80 (HTTP), Port 3306 (MySQL)

### Current Configuration

**Note:** This deployment currently uses **direct instance access** instead of an Application Load Balancer (ALB). This is ideal for:
- AWS Academy accounts with ALB restrictions
- Development and testing environments
- Cost optimization during initial setup

A section on adding an ALB is included at the end for when your AWS account is fully activated.

### Key Features

- **High Availability** - Multi-AZ deployment across 2 availability zones
- **Security** - Security groups, Secrets Manager, no hardcoded credentials
- **Scalability** - Auto Scaling Group with CPU-based scaling (2-4 instances)
- **Infrastructure as Code** - Everything version-controlled and repeatable
- **Direct Instance Access** - EC2 instances in public subnets with public IPs

---

## Architecture

### Current Architecture (Without ALB)

```
                         Internet
                            |
                    [Internet Gateway]
                            |
                 --------------------------
                 |                        |
          [Public Subnet 1]        [Public Subnet 2]
          (us-east-1a)              (us-east-1b)
                 |                        |
               [EC2]                    [EC2]
           (Public IP)              (Public IP)
                 |                        |
              [NAT Gateway]
                 |                        |
                 --------------------------
                            |
                 --------------------------
                 |                        |
             [DB Subnet 1]            [DB Subnet 2]
                 |                        |
              --------[RDS MySQL]-----------
                            |
                   [Secrets Manager]
                            |
                      [S3 Bucket]
                  (PHP Application)
```

### Infrastructure Components:

#### Networking
- **1 VPC** (10.0.0.0/16)
- **2 Public Subnets** (10.0.1.0/24, 10.0.2.0/24) - for EC2 instances
- **2 Private Subnets** (10.0.11.0/24, 10.0.12.0/24) - reserved for future use
- **2 Database Subnets** (10.0.21.0/24, 10.0.22.0/24) - for RDS
- **1 Internet Gateway** - Internet access for public subnets
- **1 NAT Gateway + Elastic IP** - Outbound internet for instances
- **Route Tables** - Proper routing for public and private traffic

#### Compute & Auto Scaling
- **Auto Scaling Group** (2-4 instances)
  - Min Size: 2
  - Desired: 2
  - Max Size: 4
- **Launch Template**
  - AMI: Amazon Linux 2 (ami-0601422bf6afa8ac3)
  - Instance Type: t3.micro
  - Key Pair: capstone-key (for SSH access)
  - User-Data: Automated setup script
- **CPU-Based Auto Scaling Policy** (target 50% CPU)

#### Database
- **RDS MySQL Instance** (db.t3.micro)
  - Engine: MySQL 8.0
  - Storage: 20 GB gp2
  - Multi-AZ: Capable (can be enabled later)
  - Database Name: country_schema

#### Security
- **Web Server Security Group**
  - Inbound: Port 22 (SSH), Port 80 (HTTP) from 0.0.0.0/0
  - Outbound: All traffic
- **RDS Security Group**
  - Inbound: Port 3306 from Web Server Security Group only
  - Outbound: All traffic
- **IAM Role for EC2**
  - S3 Read access (for PHP application files)
  - Secrets Manager Read access (for database credentials)

#### Storage & Secrets
- **S3 Bucket** - Stores PHP application files
- **Secrets Manager** - Stores database credentials securely

---

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.0)
   ```bash
   # Install on macOS
   brew install terraform

   # Install on Windows
   # Download from https://www.terraform.io/downloads

   # Install on Linux
   sudo apt-get install terraform
   ```

2. **AWS CLI** (>= 2.0)
   ```bash
   # Install AWS CLI
   # Follow: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

   # Configure credentials
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key
   # Enter default region: us-east-1
   # Enter default output format: json
   ```

3. **MySQL Client** (for database import)
   ```bash
   # macOS
   brew install mysql-client

   # Windows
   # Download from https://dev.mysql.com/downloads/mysql/

   # Linux
   sudo apt-get install mysql-client
   ```

### AWS Account Requirements

- AWS Academy Learner Lab account or regular AWS account
- Sufficient permissions to create VPC, EC2, RDS, S3, IAM resources
- No service limits on VPC, EC2, RDS creation

---

## Quick Start Deployment

### Step 1: Upload PHP Application to S3

**CRITICAL FIRST STEP:** Before deploying infrastructure, upload the PHP application files to S3.

```bash
# Navigate to project directory
cd /path/to/Capstone

# Make script executable (Linux/Mac only)
chmod +x upload-to-s3.sh

# Run the upload script
./upload-to-s3.sh
```

**What this does:**
- Creates a unique S3 bucket (e.g., `capstone-php-app-1761693785`)
- Uploads all PHP files and images from `php-app/` directory
- Automatically updates `terraform.tfvars` with the bucket name
- Saves bucket name to `.s3-bucket-name` for reference

**Wait for confirmation** message before proceeding.

### Step 2: Initialize Terraform

```bash
terraform init
```

**Expected output:** "Terraform has been successfully initialized!"

### Step 3: Review the Plan

```bash
terraform plan
```

Review the resources that will be created:
- VPC and networking components (~15 resources)
- Security groups (3 resources)
- IAM roles and policies (3 resources)
- RDS MySQL instance
- Auto Scaling Group and Launch Template
- S3 bucket references
- Secrets Manager secret

### Step 4: Deploy Infrastructure

```bash
terraform apply
```

- Review the plan
- Type `yes` when prompted
- **Wait 10-15 minutes** for completion

**What happens during deployment:**
1. VPC and networking resources created
2. Security groups configured
3. RDS database provisioning starts (longest step ~10 min)
4. EC2 instances launch with user-data script
5. User-data script runs on each instance:
   - Updates system packages (yum update)
   - Installs Apache, PHP, MySQL client
   - Starts Apache web server
   - Downloads PHP application from S3
   - Configures permissions

### Step 5: Get Instance URLs

```bash
# View all outputs
terraform output

# Get instance public IPs
aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=capstone-web-server' \
            'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[PublicDnsName,PublicIpAddress]' \
  --output table
```

**Example output:**
```
Instance 1: http://ec2-44-192-128-159.compute-1.amazonaws.com (44.192.128.159)
Instance 2: http://ec2-52-90-57-43.compute-1.amazonaws.com (52.90.57.43)
```

### Step 6: Wait for Initialization

The instances need 5-10 minutes after launching to complete setup. You can monitor progress by:

```bash
# Test if Apache is responding
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://<INSTANCE-IP>/

# Should return: HTTP 200
```

Or connect via EC2 Instance Connect and check logs:
```bash
sudo cat /var/log/user-data.log | tail -50
```

### Step 7: Test the Application

Open either instance URL in your browser:
```
http://<instance-public-ip>/
```

You should see the **Example Social Research Organization** homepage with:
- Navigation menu (About Us, Contact Us, Query)
- Logo and organization branding
- Information about Shirley Rodriguez

**Note:** The Query functionality won't work yet - you need to import the database first.

---

## Database Import

Now that the infrastructure is deployed and the application is accessible, import the country data into the RDS database.

### Option A: Import from Local Machine (Recommended)

```bash
# Get RDS endpoint
RDS_HOST=$(terraform output -raw rds_address)
echo "RDS Host: $RDS_HOST"

# Get database password from Secrets Manager
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

echo "Password retrieved successfully"

# Import the countries data
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

**If successful, you should see no errors and the command completes in a few seconds.**

### Option B: Import from EC2 Instance

1. **Connect to one of your instances via EC2 Instance Connect** (in AWS Console)

2. **Upload the SQL file** (if not already on the instance):
   ```bash
   # Option 1: If you have the file in S3
   aws s3 cp s3://your-bucket/countries.sql /tmp/countries.sql

   # Option 2: Use curl if the file is accessible via URL
   curl -o /tmp/countries.sql https://your-url/countries.sql
   ```

3. **Get database credentials**:
   ```bash
   SECRET=$(aws secretsmanager get-secret-value \
     --secret-id capstone-db-credentials \
     --region us-east-1 \
     --query SecretString \
     --output text)

   DB_HOST=$(echo $SECRET | jq -r '.host')
   DB_USER=$(echo $SECRET | jq -r '.username')
   DB_PASS=$(echo $SECRET | jq -r '.password')
   ```

4. **Import the data**:
   ```bash
   mysql -h $DB_HOST -u $DB_USER -p$DB_PASS country_schema < /tmp/countries.sql
   ```

### Verify Database Import

Test the database connection from your browser:

1. Go to either instance URL: `http://<instance-ip>/`
2. Click **Query** in the navigation menu
3. Select a query type (e.g., "Population")
4. You should see data for **227 countries**

If you see data, the import was successful! ✅

---

## Testing & Verification

### 1. Test Instance Health

```bash
# Check Auto Scaling Group health
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg \
  --query 'AutoScalingGroups[0].[DesiredCapacity,Instances[*].[InstanceId,HealthStatus,LifecycleState]]'
```

**Expected output:**
```
Desired Capacity: 2
Instances:
  - i-xxxxxxxxx: Healthy, InService
  - i-xxxxxxxxx: Healthy, InService
```

### 2. Test Web Application

Visit both instance URLs and verify:
- ✅ Homepage loads correctly
- ✅ Logo and images display
- ✅ Navigation menu works
- ✅ "Query" page loads
- ✅ All 5 query types return data:
  - Mobile phones per 100 people
  - Population
  - Life Expectancy
  - Mortality Rate
  - GDP per capita

### 3. Test Database Queries

Click each query type and verify:
- Data loads for all 227 countries
- No error messages
- Results sorted correctly

### 4. Test SSH Access

```bash
# Connect to instance using the key pair
ssh -i "capstone-key.pem" ec2-user@<instance-public-ip>

# Once connected, verify services
sudo systemctl status httpd     # Apache should be active
ls -la /var/www/html/           # Should show PHP files
```

### 5. Check RDS Connection

```bash
# From your local machine or EC2 instance
mysql -h <rds-endpoint> -u admin -p<password> -e "USE country_schema; SELECT COUNT(*) FROM countries;"
```

**Expected output:** `227` (number of countries)

### 6. Monitor Auto Scaling

Test that auto-scaling works:
```bash
# Check current status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg

# View scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name capstone-asg \
  --max-records 10
```

---

## Load Balancer Setup (Optional)

**This section is for future use when your AWS account is fully activated and supports Application Load Balancers.**

### Why Add a Load Balancer?

Currently, your setup uses direct instance access. Adding an ALB provides:
- ✅ **Single URL** - One DNS name instead of multiple instance IPs
- ✅ **High Availability** - Traffic distributed across healthy instances
- ✅ **Health Checks** - Automatic detection and routing around failed instances
- ✅ **SSL/TLS** - Easy HTTPS setup with ACM certificates
- ✅ **Production Ready** - Industry best practice for web applications

### Architecture with ALB

```
                         Internet
                            |
                    [Internet Gateway]
                            |
                 --------------------------
                 |                        |
          [Public Subnet 1]        [Public Subnet 2]
                 |                        |
        ----------[Application Load Balancer]----------
                            |
                      [NAT Gateway]
                            |
                 --------------------------
                 |                        |
          [Private Subnet 1]       [Private Subnet 2]
                 |                        |
               [EC2]                    [EC2]
            (No Public IP)          (No Public IP)
                 |                        |
                 --------------------------
                            |
                 --------------------------
                 |                        |
             [DB Subnet 1]            [DB Subnet 2]
                 |                        |
              --------[RDS MySQL]-----------
```

### Steps to Enable ALB

#### 1. Uncomment ALB Resources in `main.tf`

Find and uncomment these sections:

```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "capstone-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "capstone-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "capstone-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health.txt"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

#### 2. Update Auto Scaling Group

Change the ASG configuration to use private subnets:

```hcl
resource "aws_autoscaling_group" "web" {
  name                      = "capstone-asg"
  vpc_zone_identifier       = [aws_subnet.private_1.id, aws_subnet.private_2.id]  # Changed from public
  target_group_arns         = [aws_lb_target_group.main.arn]                      # Uncommented
  health_check_type         = "ELB"                                                # Changed from EC2
  health_check_grace_period = 400
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 2

  # ... rest of config
}
```

#### 3. Update Security Groups

```hcl
# Web Server Security Group - Remove public HTTP access
resource "aws_security_group" "web" {
  name        = "capstone-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # Remove or comment out public HTTP access
  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # Add ALB access
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow HTTP from ALB only"
  }

  # ... SSH and egress rules
}
```

#### 4. Add ALB Output

Add to `outputs.tf`:

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

#### 5. Apply Changes

```bash
terraform plan    # Review the changes
terraform apply   # Type 'yes' to apply
```

#### 6. Access via ALB

After deployment:
```bash
terraform output alb_url
```

Use the ALB URL to access your application. The ALB will distribute traffic across healthy instances.

### ALB Benefits Summary

| Feature | Without ALB (Current) | With ALB |
|---------|----------------------|----------|
| **Access** | Multiple instance IPs | Single DNS name |
| **High Availability** | Manual failover | Automatic failover |
| **Health Checks** | EC2 status checks only | Application-level health |
| **SSL/TLS** | Manual cert management | Easy ACM integration |
| **Cost** | Lower (~$20-30/month) | Higher (~$50-80/month) |
| **Best For** | Development, Testing | Production |

---

## Cost Management

### Current Cost Breakdown

**Monthly estimates (us-east-1 region):**

| Resource | Cost | Notes |
|----------|------|-------|
| **NAT Gateway** | ~$32/month | $0.045/hour + data transfer |
| **RDS db.t3.micro** | ~$12/month | $0.017/hour |
| **EC2 t3.micro (×2)** | ~$17/month | $0.0116/hour each |
| **EBS volumes** | ~$2/month | 8GB per instance |
| **Elastic IP** | $0 | Free when attached to NAT |
| **S3 Storage** | ~$0.50 | <1GB storage |
| **Data Transfer** | Varies | First 100GB free |

**Total: ~$60-65/month** (without ALB)

**With ALB added: ~$80-95/month**

### Cost Optimization Strategies

#### 1. Stop Resources When Not in Use

```bash
# Stop RDS instance (will auto-start after 7 days)
aws rds stop-db-instance --db-instance-identifier capstone-mysql-db

# Scale down to 0 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 0

# Set minimum to 0 (prevents auto-scaling back up)
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name capstone-asg \
  --min-size 0
```

#### 2. Delete NAT Gateway (Breaks Internet for Private Instances)

**Warning:** Only do this if you don't need internet access for instances.

```bash
# Get NAT Gateway ID
NAT_ID=$(aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=capstone-nat" \
  --query 'NatGateways[0].NatGatewayId' \
  --output text)

# Delete NAT Gateway
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID

# Release Elastic IP (after NAT is deleted)
EIP_ID=$(terraform output -raw nat_gateway_public_ip)
aws ec2 release-address --allocation-id <eip-allocation-id>
```

**Savings: ~$32/month**

#### 3. Use Smaller Instance Types

Edit `terraform.tfvars`:
```hcl
instance_type = "t2.micro"  # Even cheaper than t3.micro
db_instance_class = "db.t2.micro"
```

Then run:
```bash
terraform apply
```

#### 4. Set Up Budget Alerts

```bash
# Create a $50 monthly budget
aws budgets create-budget \
  --account-id <your-account-id> \
  --budget file://budget.json \
  --notifications-with-subscribers file://notifications.json
```

#### 5. Complete Teardown When Done

```bash
terraform destroy
```

Type `yes` to confirm. This deletes everything and stops all charges.

**Important:** Delete the S3 bucket manually if you want:
```bash
BUCKET_NAME=$(cat .s3-bucket-name)
aws s3 rb s3://$BUCKET_NAME --force
```

---

## Troubleshooting

### Issue: Instances Not Accessible via HTTP

**Symptoms:** Browser shows "took too long to respond" or connection refused.

**Solutions:**

1. **Check if Apache is running:**
   ```bash
   # SSH into instance
   ssh -i "capstone-key.pem" ec2-user@<instance-ip>

   # Check Apache status
   sudo systemctl status httpd

   # If not running, start it
   sudo systemctl start httpd
   ```

2. **Check Security Group:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids sg-<your-web-sg-id> \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]'
   ```

   Should show port 80 open to 0.0.0.0/0.

3. **Check User-Data Logs:**
   ```bash
   sudo cat /var/log/user-data.log | tail -100
   ```

   Look for errors in package installation or S3 download.

4. **Test locally on instance:**
   ```bash
   curl http://localhost/
   ```

   If this works but external access doesn't, it's a security group issue.

### Issue: SSH Connection Refused

**Symptoms:** `ssh: connect to host X port 22: Connection refused`

**Solutions:**

1. **Verify Security Group allows SSH:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <web-sg-id> \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]'
   ```

2. **Check if key pair is attached:**
   ```bash
   aws ec2 describe-instances \
     --instance-ids <instance-id> \
     --query 'Reservations[0].Instances[0].KeyName'
   ```

3. **Verify key permissions:**
   ```bash
   chmod 400 capstone-key.pem
   ```

4. **Use EC2 Instance Connect** in AWS Console as alternative.

### Issue: Database Connection Failed

**Symptoms:** PHP application shows "Database connection failed" error.

**Solutions:**

1. **Check RDS is running:**
   ```bash
   aws rds describe-db-instances \
     --db-instance-identifier capstone-mysql-db \
     --query 'DBInstances[0].DBInstanceStatus'
   ```

   Should return `"available"`.

2. **Verify Security Group allows MySQL:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <rds-sg-id> \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`3306`]'
   ```

   Should allow traffic from web server security group.

3. **Test connection from instance:**
   ```bash
   # SSH into web instance
   mysql -h <rds-endpoint> -u admin -p
   ```

4. **Check Secrets Manager:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id capstone-db-credentials \
     --query SecretString \
     --output text
   ```

### Issue: PHP Application Files Not Loading

**Symptoms:** Blank page or "file not found" errors.

**Solutions:**

1. **Check files exist:**
   ```bash
   ssh -i "capstone-key.pem" ec2-user@<instance-ip>
   ls -la /var/www/html/
   ```

   Should show `index.php`, `query.php`, etc.

2. **Check S3 download in logs:**
   ```bash
   sudo cat /var/log/user-data.log | grep "Step 11"
   ```

3. **Verify IAM role has S3 permissions:**
   ```bash
   aws iam get-role-policy \
     --role-name capstone-ec2-role \
     --policy-name capstone-s3-policy
   ```

4. **Manually download from S3:**
   ```bash
   aws s3 sync s3://capstone-php-app-XXXXXXX/php-app/ /var/www/html/
   sudo chown -R apache:apache /var/www/html/
   ```

### Issue: Terraform Apply Fails

**Common errors and solutions:**

1. **"Error creating VPC"**
   - Check VPC limits in your AWS account
   - Ensure you have permissions to create VPCs

2. **"Error creating RDS instance"**
   - Check RDS quota limits
   - Verify region supports db.t3.micro
   - Wait a few minutes and retry

3. **"InvalidAMIID.NotFound"**
   - AMI ID might be region-specific
   - Update `data.tf` to use correct AMI filter

4. **"Exceeded maximum number of addresses"**
   - Release unused Elastic IPs
   - Check EIP quota in your account

5. **Authentication errors:**
   ```bash
   aws sts get-caller-identity  # Verify credentials work
   aws configure                # Reconfigure if needed
   ```

### Issue: Auto Scaling Not Working

**Symptoms:** Instances not scaling up/down as expected.

**Solutions:**

1. **Check Auto Scaling Group:**
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --auto-scaling-group-names capstone-asg
   ```

2. **Check Scaling Activities:**
   ```bash
   aws autoscaling describe-scaling-activities \
     --auto-scaling-group-name capstone-asg \
     --max-records 10
   ```

3. **Manually trigger scaling:**
   ```bash
   # Scale up
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name capstone-asg \
     --desired-capacity 3

   # Scale down
   aws autoscaling set-desired-capacity \
     --auto-scaling-group-name capstone-asg \
     --desired-capacity 2
   ```

---

## Cleanup

### Complete Infrastructure Teardown

When you're done with the project:

```bash
# Destroy all Terraform-managed resources
terraform destroy
```

Type `yes` to confirm.

**This will delete:**
- ✅ All EC2 instances
- ✅ Auto Scaling Group and Launch Template
- ✅ RDS database (and all data)
- ✅ VPC and all networking components
- ✅ Security groups
- ✅ NAT Gateway and Elastic IP
- ✅ IAM roles and policies
- ✅ Secrets Manager secret

**This will NOT delete:**
- ❌ S3 bucket (must be deleted manually)
- ❌ SSH key pair (capstone-key)

### Delete S3 Bucket

```bash
# Get bucket name
BUCKET_NAME=$(cat .s3-bucket-name)

# Delete all objects and bucket
aws s3 rb s3://$BUCKET_NAME --force
```

### Delete SSH Key Pair

```bash
# Delete from AWS
aws ec2 delete-key-pair --key-name capstone-key

# Delete local file
rm capstone-key.pem
```

### Verify Complete Cleanup

```bash
# Check for remaining resources
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=capstone-vpc"
aws rds describe-db-instances --db-instance-identifier capstone-mysql-db
aws ec2 describe-instances --filters "Name=tag:Name,Values=capstone-web-server"
```

All commands should return empty results.

---

## Additional Resources

### AWS Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Auto Scaling Best Practices](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-best-practices.html)
- [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)

### Terraform Learning
- [Terraform AWS Tutorials](https://learn.hashicorp.com/collections/terraform/aws-get-started)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Security
- [AWS Security Best Practices](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-standards-fsbp.html)
- [Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)

---

## Project Information

**Version:** 2.0 (Updated for current deployment configuration)
**Last Updated:** October 2025
**Terraform Version:** >= 1.0
**AWS Provider Version:** >= 5.0

**Course:** AWS Academy Cloud Architecting
**Purpose:** Educational - Capstone Project Implementation

---

## Success Checklist

Use this checklist to verify your deployment:

- [ ] S3 bucket created and PHP files uploaded
- [ ] Terraform init completed successfully
- [ ] Terraform apply completed without errors
- [ ] 2 EC2 instances running in different AZs
- [ ] Both instances accessible via public IPs
- [ ] PHP application homepage loads on both instances
- [ ] RDS database is available
- [ ] Database credentials stored in Secrets Manager
- [ ] Countries data imported (227 countries)
- [ ] All 5 query types return data
- [ ] SSH access works with capstone-key.pem
- [ ] Auto Scaling Group shows healthy instances
- [ ] Security groups configured correctly
- [ ] NAT Gateway provides outbound internet access

**If all items are checked, your deployment is successful!** ✅

---

## Next Steps

After completing the basic deployment:

1. **Explore the Application** - Test all query types thoroughly
2. **Monitor Costs** - Set up AWS Budgets and check Cost Explorer
3. **Implement ALB** - When your AWS account supports it (see ALB section)
4. **Add HTTPS** - Request ACM certificate and configure SSL on ALB
5. **Enable Multi-AZ RDS** - For true high availability
6. **Set Up Monitoring** - Configure CloudWatch alarms and dashboards
7. **Implement Backups** - Configure automated RDS snapshots
8. **Custom Domain** - Use Route 53 to point your domain to the application

---

*This guide is maintained as part of the AWS Academy Capstone Project.*
*For questions or issues, refer to the Troubleshooting section or consult AWS documentation.*
