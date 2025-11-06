# Complete Guide - AWS Capstone Terraform Infrastructure

**Version:** 2.1
**Last Updated:** November 6, 2025
**Author:** Terraform-managed AWS Infrastructure

---


## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Prerequisites](#2-prerequisites)
3. [Resource Verification Commands](#3-resource-verification-commands)
4. [File-by-File Documentation](#4-file-by-file-documentation)
5. [Deployment Instructions](#5-deployment-instructions)
6. [Database Setup](#6-database-setup)
7. [Application Deployment](#7-application-deployment)
8. [Troubleshooting](#8-troubleshooting)
9. [Cost Optimization](#9-cost-optimization)
10. [Security Best Practices](#10-security-best-practices)

---

## 1. Architecture Overview

### 1.1 High-Level Architecture

This infrastructure deploys a **production-grade, highly available PHP web application** on AWS with the following components:

```
                                    ┌─────────────────┐
                                    │   Internet      │
                                    └────────┬────────┘
                                             │
                                    ┌────────▼────────┐
                                    │ Internet Gateway│
                                    └────────┬────────┘
                                             │
                 ┌───────────────────────────┴───────────────────────────┐
                 │                                                       │
        ┌────────▼────────┐                                   ┌─────────▼────────┐
        │ Public Subnet 1 │                                   │ Public Subnet 2  │
        │   10.0.1.0/24   │                                   │   10.0.2.0/24    │
        │   (us-east-1a)  │                                   │   (us-east-1b)   │
        └────────┬────────┘                                   └─────────┬────────┘
                 │                                                       │
        ┌────────▼────────┐                                   ┌─────────▼────────┐
        │  EC2 Instance 1 │                                   │  EC2 Instance 2  │
        │  (Auto Scaling) │                                   │  (Auto Scaling)  │
        │  98.92.143.68   │                                   │  54.165.28.132   │
        └────────┬────────┘                                   └─────────┬────────┘
                 │                                                       │
                 └───────────────────────────┬───────────────────────────┘
                                             │
                                    ┌────────▼────────┐
                                    │  NAT Gateway    │
                                    │  (98.95.22.13)  │
                                    └────────┬────────┘
                                             │
                 ┌───────────────────────────┴───────────────────────────┐
                 │                                                       │
        ┌────────▼────────┐                                   ┌─────────▼────────┐
        │  DB Subnet 1    │                                   │  DB Subnet 2     │
        │  10.0.21.0/24   │                                   │  10.0.22.0/24    │
        │  (us-east-1a)   │                                   │  (us-east-1b)    │
        └────────┬────────┘                                   └─────────┬────────┘
                 │                                                       │
                 └───────────────────────────┬───────────────────────────┘
                                             │
                                    ┌────────▼────────────────────┐
                                    │    RDS MySQL Database       │
                                    │  Multi-AZ (Standby Ready)   │
                                    │  capstone-mysql-db          │
                                    └─────────────────────────────┘

        ┌─────────────────────────────────────────────────────────────┐
        │                  Supporting Services                        │
        ├─────────────────────────────────────────────────────────────┤
        │  • AWS Secrets Manager (DB Credentials)                     │
        │  • S3 Bucket (PHP Application Files)                        │
        │  • IAM Roles & Policies (EC2 Access Control)                │
        │  • Security Groups (Network Firewall Rules)                 │
        │  • Auto Scaling Group (2-4 instances)                       │
        └─────────────────────────────────────────────────────────────┘
```

### 1.2 Why This Architecture is Solid

This architecture follows AWS best practices and demonstrates enterprise-grade design:

#### **High Availability**
- **Multi-AZ Deployment:** Resources span 2 availability zones (us-east-1a and us-east-1b) to ensure zero downtime if one AZ fails
- **Auto Scaling Group:** Automatically maintains 2-4 instances, replacing unhealthy instances within minutes
- **RDS Multi-AZ Ready:** Database subnet group configured across 2 AZs for automatic failover capability

#### **Security**
- **Defense in Depth:** Multiple layers of security (Security Groups, IAM, Secrets Manager)
- **Least Privilege IAM:** EC2 instances only have permissions for specific resources (Secrets Manager, S3)
- **Network Segmentation:** Separate subnets for web, database, and public access with strict security group rules
- **Secrets Management:** Database credentials stored in AWS Secrets Manager, never hardcoded
- **Private Database:** RDS in private subnets, only accessible from web tier security group

#### **Scalability**
- **Auto Scaling:** CPU-based scaling policy (target 50% CPU) automatically adds/removes instances
- **Stateless Application:** PHP app can scale horizontally without session issues
- **Load Balancer Ready:** Infrastructure prepared for ALB addition when needed

#### **Cost Optimization**
- **Right-Sized Instances:** t3.micro instances with burstable CPU for variable workloads
- **NAT Gateway Sharing:** Single NAT Gateway shared across both AZs (development mode)
- **S3 for Static Assets:** PHP files stored in S3, reducing instance storage costs

#### **Operational Excellence**
- **Infrastructure as Code:** Entire infrastructure defined in Terraform for reproducibility
- **Automated Provisioning:** User-data script fully automates instance configuration
- **Monitoring Ready:** CloudWatch integration built-in for all resources
- **Easy Recovery:** Terraform state enables quick disaster recovery

---

## 2. Prerequisites

### 2.1 Required Tools

```bash
# Check if tools are installed
terraform --version    # Required: >= 1.0
aws --version          # Required: AWS CLI v2
mysql --version        # Required for database import
jq --version          # Required for JSON parsing
```

### 2.2 AWS Credentials

Ensure AWS credentials are configured:
---
- Preserves health.txt file
- Creates fallback HTML if S3 fails

**Step 10: File Verification (Lines 243-259)**
    
- **Query Results:** Tables with country data

---

### 5.2 Updating Existing Infrastructure

**Scenario:** You made changes to Terraform configuration or PHP files.

**Update Terraform Resources:**
```bash
terraform plan
terraform apply
```

**Update PHP Application:**
```bash
# 1. Update files in php-app/
vim php-app/get-parameters.php

# 2. Upload to S3
aws s3 sync php-app/ s3://capstone-php-app-1761693785/php-app/ --region us-east-1

# 3. Refresh instances (forces re-download)
# Option A: Terminate instances (ASG will create new ones)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 0 \
  --region us-east-1

# Wait 30 seconds, then restore
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 2 \
  --region us-east-1

# Option B: Manually update on each instance
ssh -i capstone-key.pem ec2-user@98.92.143.68
sudo aws s3 cp s3://capstone-php-app-1761693785/php-app/get-parameters.php /var/www/html/get-parameters.php --region us-east-1
sudo chown apache:apache /var/www/html/get-parameters.php
sudo systemctl restart httpd
```

---

## 6. Database Setup

### 6.1 Automatic Import (via user-data.sh)

The database is automatically imported during EC2 instance launch. The `user-data.sh` script handles:
1. Downloading `countries.sql` from S3
2. Retrieving credentials from Secrets Manager
3. Waiting for RDS to be available (up to 5 minutes)
4. Importing the schema and data
5. Verifying the import (231 countries)

**Prerequisites:**
- `countries.sql` must be uploaded to S3 bucket root:
```bash
aws s3 cp countries.sql s3://capstone-php-app-1761693785/ --region us-east-1
```

**Verify automatic import:**
```bash
# SSH to instance
ssh -i capstone-key.pem ec2-user@98.92.143.68

# Check logs
sudo cat /var/log/user-data.log | grep -A 20 "Importing database"
```

Expected output:
```
Importing countries data...
✓ Database imported successfully
✓ Imported 231 countries
```

---

### 6.2 Manual Import

In this capstone project, the database was imported manually following these steps. You can do the same:

**Step 1: Get Database Credentials**
```bash
# Get RDS endpoint
RDS_HOST=$(terraform output -raw rds_address)

# Get password from Secrets Manager
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

echo "Host: $RDS_HOST"
echo "Password: $DB_PASS"
```

**Step 2: Import Database**
```bash
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

**Step 3: Verify Import**
```bash
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema \
  -e "SELECT COUNT(*) as total_countries FROM countrydata_final;"
```

Expected: `231`

**Step 4: Sample Query**
```bash
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema \
  -e "SELECT name, population, gdp FROM countrydata_final WHERE name LIKE 'United%';"
```

---

### 6.3 Database Schema

**Table: `countrydata_final`**

| Column | Type | Description |
|--------|------|-------------|
| name | text | Country name |
| mobilephones | double | Number of mobile phone subscribers |
| mortalityunder5 | double | Under-5 mortality rate per 1,000 |
| healthexpenditurepercapita | double | Health spending per capita (USD) |
| healthexpenditureppercentGDP | double | Health spending as % of GDP |
| population | double | Total population |
| populationurban | double | Urban population |
| birthrate | double | Birth rate per 1,000 |
| lifeexpectancy | double | Life expectancy (years) |
| GDP | double | Gross Domestic Product (USD) |

---

## 7. Application Deployment

### 7.1 Application Architecture

The PHP application follows a simple query-response pattern:

```
User Browser
     │
     ▼
index.php (Homepage)
     │
     ▼
query.php (Query Selection)
     │
     ▼
query2.php (Dispatcher)
     │
     ├─→ mobile.php ────┐
     ├─→ population.php ┤
     ├─→ gdp.php ───────┤
     ├─→ mortality.php ─┤
     └─→ lifeexpectancy.php
              │
              ▼
     get-parameters.php (DB Connection)
              │
              ▼
       RDS MySQL Database
```

**Key Flow:**
1. User selects query type (Q1-Q5)
2. `query2.php` includes appropriate query file
3. Query file includes `get-parameters.php` to get DB credentials
4. Executes SQL query and displays HTML table

---

### 7.2 Testing Application

**Access Application URLs:**
```bash
# Get URLs from Terraform
terraform output instance_public_urls

# Test each instance
curl -s http://98.92.143.68/ | grep "Example Social Research"
curl -s http://54.165.28.132/ | grep "Example Social Research"
```

**Test Query Functionality:**
```bash
# Test mobile phones query
curl -s -X POST "http://98.92.143.68/query2.php" -d "selection=Q1" | grep "Afghanistan"

# Test population query
curl -s -X POST "http://54.165.28.132/query2.php" -d "selection=Q2" | grep "population"
```

**Expected Results:**
- Homepage displays organization information
- Query page shows dropdown with 5 options
- Each query returns data in HTML table format
- Data includes 231 countries

---

## 8. Troubleshooting

### 8.1 Common Deployment Issues

#### **Issue: Terraform Apply Fails with "EntityAlreadyExists"**

**Error:**
```
Error: creating IAM Role (capstone-ec2-role): EntityAlreadyExists: Role with name capstone-ec2-role already exists
```

**Cause:** Previous deployment wasn't fully destroyed

**Solution:**
```bash
# Import existing resource
terraform import aws_iam_role.ec2_role capstone-ec2-role

# Then apply
terraform apply
```

---

#### **Issue: EC2 Instances Not Downloading from S3**

**Symptoms:**
- Instances show "Deployment Error" page
- `/var/log/user-data.log` shows S3 download failed

**Diagnosis:**
```bash
# SSH to instance
ssh -i capstone-key.pem ec2-user@<instance-ip>

# Check logs
sudo cat /var/log/user-data.log | grep S3

# Test S3 access manually
aws s3 ls s3://capstone-php-app-1761693785/php-app/
```

**Common Causes:**
1. **Wrong bucket name in terraform.tfvars**
   ```bash
   # Check current value
   grep s3_php_app_bucket terraform.tfvars

   # Verify bucket exists
   aws s3 ls | grep capstone
   ```

2. **IAM role missing S3 permissions**
   ```bash
   # Check instance role
   aws ec2 describe-instances --instance-ids <id> \
     --query 'Reservations[0].Instances[0].IamInstanceProfile'

   # Check role policies
   aws iam list-role-policies --role-name capstone-ec2-role
   ```

3. **S3 bucket empty**
   ```bash
   # Verify files in bucket
   aws s3 ls s3://capstone-php-app-1761693785/php-app/ --recursive

   # If empty, re-upload
   ./upload-to-s3.sh
   ```

---

#### **Issue: Application Shows "Connection Error" to Database**

**Symptoms:**
- Query pages display database connection errors
- PHP error logs show "Connection refused" or "Access denied"

**Diagnosis:**
```bash
# SSH to instance
ssh -i capstone-key.pem ec2-user@<instance-ip>

# Check if RDS is reachable
RDS_HOST=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.host')

mysql -h $RDS_HOST -u admin -p -e "SELECT 1"
```

**Common Causes:**
1. **Security group misconfiguration**
   ```bash
   # Check web server SG ID
   WEB_SG=$(aws ec2 describe-instances --instance-ids <id> \
     --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
     --output text)

   # Check RDS allows web SG
   aws ec2 describe-security-groups \
     --filters "Name=group-name,Values=capstone-rds-sg" \
     --query 'SecurityGroups[0].IpPermissions'
   ```

2. **Database not imported**
   ```bash
   # Connect and check table
   mysql -h $RDS_HOST -u admin -p country_schema \
     -e "SHOW TABLES; SELECT COUNT(*) FROM countrydata_final;"
   ```

3. **Wrong credentials in Secrets Manager**
   ```bash
   # Verify secret contents
   aws secretsmanager get-secret-value \
     --secret-id capstone-db-credentials \
     --region us-east-1 \
     --query SecretString \
     --output text | jq '.'
   ```

---

#### **Issue: Auto Scaling Not Launching Instances**

**Symptoms:**
- ASG shows 0 instances
- Scaling activities show failures

**Diagnosis:**
```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg \
  --region us-east-1

# View recent scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name capstone-asg \
  --max-records 10 \
  --region us-east-1 \
  --query 'Activities[].{Time:StartTime,Description:Description,Status:StatusCode,Cause:Cause}'
```

**Common Causes:**
1. **Launch template references missing AMI**
2. **Subnet quota exceeded**
3. **Instance type not available in AZ**

**Solution:**
```bash
# Force new instances
terraform taint aws_launch_template.web
terraform apply
```

---

### 8.2 Application Debugging

#### **Enable PHP Error Display**

**SSH to instance:**
```bash
ssh -i capstone-key.pem ec2-user@<instance-ip>

# Edit PHP configuration
sudo vi /etc/php.ini

# Change these lines:
display_errors = On
error_reporting = E_ALL

# Restart Apache
sudo systemctl restart httpd
```

**View PHP errors in browser or logs:**
```bash
sudo tail -f /var/log/httpd/error_log
```

---

#### **Test Database Connection Manually**

Create test file on instance:
```bash
sudo tee /var/www/html/test-db.php > /dev/null << 'EOF'
<?php
require '/var/www/html/vendor/autoload.php';

$secrets_client = new Aws\SecretsManager\SecretsManagerClient([
  'version' => 'latest',
  'region'  => 'us-east-1'
]);

$result = $secrets_client->getSecretValue([
  'SecretId' => 'capstone-db-credentials',
]);

$secret = json_decode($result['SecretString'], true);

echo "Host: " . $secret['host'] . "<br>";
echo "User: " . $secret['username'] . "<br>";
echo "Database: " . $secret['dbname'] . "<br>";

$conn = new mysqli($secret['host'], $secret['username'], $secret['password'], $secret['dbname']);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

echo "Connected successfully!<br>";

$result = $conn->query("SELECT COUNT(*) as total FROM countrydata_final");
$row = $result->fetch_assoc();
echo "Total countries: " . $row['total'];
?>
EOF

# Set permissions
sudo chown apache:apache /var/www/html/test-db.php

# Access via browser: http://<instance-ip>/test-db.php
```

Expected output:
```
Host: capstone-mysql-db.ck9uegaac4l0.us-east-1.rds.amazonaws.com
User: admin
Database: country_schema
Connected successfully!
Total countries: 231
```

---

### 8.3 Network Debugging

#### **Test Internet Connectivity**
```bash
ssh -i capstone-key.pem ec2-user@<instance-ip>

# Test outbound internet
curl -I https://google.com

# Test AWS API access
aws s3 ls

# Test RDS connectivity
nc -zv capstone-mysql-db.ck9uegaac4l0.us-east-1.rds.amazonaws.com 3306
```

---

#### **Check Security Group Rules**
```bash
# Get instance security group
aws ec2 describe-instances --instance-ids <id> \
  --query 'Reservations[0].Instances[0].SecurityGroups'

# View detailed rules
aws ec2 describe-security-groups --group-ids <sg-id>
```

---

## 9. Cost Optimization

### 9.1 Current Monthly Costs (us-east-1)

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| EC2 t3.micro | 2 instances | $0.0104/hr | $15.08 |
| RDS db.t3.micro | 1 instance | $0.017/hr | $12.41 |
| RDS Storage (20GB) | 20GB | $0.115/GB | $2.30 |
| NAT Gateway | 1 gateway | $0.045/hr | $32.85 |
| NAT Data Transfer | ~10GB | $0.045/GB | $0.45 |
| Elastic IP (NAT) | 1 IP | $0.00/hr | $0.00 |
| S3 Storage | <1GB | $0.023/GB | $0.02 |
| S3 Requests | ~100 | Minimal | $0.01 |
| Secrets Manager | 1 secret | $0.40/month | $0.40 |
| **TOTAL** | | | **$63.52/month** |

### 9.2 Cost Reduction Strategies

#### **Development Environment (Est. $18/month)**
```hcl
# terraform.tfvars changes
asg_min_size         = 1   # Down from 2
asg_max_size         = 2   # Down from 4
asg_desired_capacity = 1   # Down from 2

# Comment out NAT Gateway in main.tf
# Use public subnets for all resources
```

**Savings:** ~$45/month (removed NAT Gateway + 1 instance)

---

#### **Spot Instances (Save 70% on EC2)**
```hcl
resource "aws_autoscaling_group" "web" {
  # Add spot instance configuration
  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.web.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.micro"
      }
    }
  }
}
```

**Savings:** ~$10/month on EC2

---

#### **RDS Reserved Instance (Save 40%)**

Purchase 1-year reserved instance for RDS:
```bash
aws rds purchase-reserved-db-instances-offering \
  --reserved-db-instances-offering-id <offering-id> \
  --db-instance-count 1
```

**Savings:** ~$5/month

---

#### **Scheduled Scaling (Dev Hours Only)**

Auto-stop instances outside business hours:
```bash
# Add Lambda function to stop instances at 6 PM
# Start instances at 8 AM
# Runs only on weekdays
```

**Savings:** ~$25/month (75% time reduction)

---

### 9.3 Free Tier Eligible Resources

**AWS Free Tier (First 12 months):**
- EC2: 750 hours/month t2.micro or t3.micro
- RDS: 750 hours/month db.t2.micro or db.t3.micro
- S3: 5GB storage, 20,000 GET requests
- NAT Gateway: Not free tier eligible
- Secrets Manager: 30-day free trial, then $0.40/month

**Strategy:** Stay within free tier limits:
```hcl
# Free tier configuration
instance_type = "t3.micro"  # ✓ Free tier eligible
db_instance_class = "db.t3.micro"  # ✓ Free tier eligible
asg_desired_capacity = 1  # ✓ Within 750 hours/month
```

---

## 10. Security Best Practices

### 10.1 Current Security Posture

**✅ Implemented:**
- Secrets Manager for database credentials
- Security groups with least privilege
- IAM roles with specific resource ARNs
- Private database subnets
- SSH key authentication only

**⚠️ Needs Improvement:**
- SSH open to 0.0.0.0/0 (should restrict to your IP)
- HTTP only (no HTTPS)
- No WAF or DDoS protection
- Secrets Manager has 0-day recovery window (production should be 7-30 days)

---

### 10.2 Security Hardening Recommendations

#### **10.2.1 Restrict SSH Access**

**Current:**
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ⚠️ Open to world
}
```

**Improved:**
```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["YOUR_IP/32"]  # ✅ Only your IP
  description = "SSH from my IP only"
}
```

**Get your IP:**
```bash
curl -s https://checkip.amazonaws.com
```

---

#### **10.2.2 Enable HTTPS**

**Prerequisites:**
- Domain name (e.g., capstone.example.com)
- ACM certificate

**Steps:**
1. Request ACM certificate
2. Add Application Load Balancer with HTTPS listener
3. Redirect HTTP to HTTPS

---

#### **10.2.3 Enable RDS Encryption**

```hcl
resource "aws_db_instance" "main" {
  # ...existing config...
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
}
```

---

#### **10.2.4 Enable S3 Bucket Encryption**

```bash
aws s3api put-bucket-encryption \
  --bucket capstone-php-app-1761693785 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

---

#### **10.2.5 Enable CloudTrail Logging**

```hcl
resource "aws_cloudtrail" "capstone" {
  name                          = "capstone-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
}
```

---

#### **10.2.6 Implement Secrets Rotation**

```hcl
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

---

### 10.3 Compliance Checklist

**AWS Well-Architected Framework - Security Pillar:**

- [x] IAM roles instead of access keys
- [x] Secrets in Secrets Manager (not hardcoded)
- [x] Security groups (not network ACLs alone)
- [x] Private database subnets
- [ ] MFA for root account
- [ ] CloudTrail enabled
- [ ] Encryption at rest (RDS, S3)
- [ ] Encryption in transit (HTTPS)
- [ ] Regular security audits
- [ ] Automated vulnerability scanning

---

## Appendix A: Quick Reference Commands

### Terraform Operations
```bash
terraform init                    # Initialize
terraform plan                    # Preview changes
terraform apply                   # Deploy
terraform destroy                 # Delete all resources
terraform output                  # Show outputs
terraform state list              # List resources
terraform fmt                     # Format code
terraform validate                # Validate syntax
```

### AWS CLI - EC2
```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=capstone-web-server"

# Get instance IPs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=capstone-web-server" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,PublicIpAddress]' \
  --output table

# SSH to instance
ssh -i capstone-key.pem ec2-user@<ip>

# Terminate instance (ASG will replace)
aws ec2 terminate-instances --instance-ids <id>
```

### AWS CLI - RDS
```bash
# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier capstone-mysql-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Connect to database
mysql -h $(terraform output -raw rds_address) -u admin -p
```

### AWS CLI - Auto Scaling
```bash
# Get ASG details
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg

# Change desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 3

# Trigger instance refresh
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name capstone-asg
```

### AWS CLI - Secrets Manager
```bash
# Get secret value
aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --query 'SecretString' \
  --output text | jq '.'

# Update secret
aws secretsmanager update-secret \
  --secret-id capstone-db-credentials \
  --secret-string '{"username":"admin","password":"newpass123"}'
```

### Debugging Commands
```bash
# SSH and check logs
ssh -i capstone-key.pem ec2-user@<ip>
sudo cat /var/log/user-data.log
sudo tail -f /var/log/httpd/error_log
sudo systemctl status httpd

# Test database connection
mysql -h <rds-endpoint> -u admin -p country_schema

# Test S3 access from instance
aws s3 ls s3://capstone-php-app-1761693785/php-app/

# Test PHP
curl http://localhost/test-db.php
```

---

## Summary

This deployment guide provides a complete reference for understanding, deploying, and maintaining the Capstone Terraform infrastructure. Key takeaways:

1. **Architecture is production-ready** with multi-AZ, auto-scaling, and security best practices
2. **All resources are documented** with purpose, configuration, and relationships
3. **Deployment is fully automated** via Terraform and user-data scripts
4. **Costs are optimized** at ~$64/month with strategies to reduce to $18/month
5. **Security is layered** but has room for hardening (HTTPS, restricted SSH, encryption)
6. **Code has been cleaned** - removed unused ALB resources, simplified database section


**Next Steps:**
1. Consider modularizing Terraform code
2. Apply security hardening (Section 10.2)
3. Set up remote state for team collaboration (Appendix B)
4. Implement CI/CD pipeline (Appendix C)

For questions or issues, refer to the Troubleshooting section or AWS documentation.

---

**Document Version:** 2.1
**Last Updated:** November 6, 2025
**Maintained By:** Nada EL ANNASI, Wassila ASRI, Anas EL BOUZIYANI, Ahmed LAHMADI