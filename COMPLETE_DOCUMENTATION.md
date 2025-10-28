# AWS Academy Capstone Project - Complete Documentation
## Terraform Infrastructure as Code - Full Guide

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Files & Structure](#files--structure)
4. [Prerequisites](#prerequisites)
5. [Quick Start Guide](#quick-start-guide)
6. [Detailed Deployment](#detailed-deployment)
7. [Database Import](#database-import)
8. [Image Files Setup](#image-files-setup)
9. [PHP Application Details](#php-application-details)
10. [Testing & Verification](#testing--verification)
11. [Cost Management](#cost-management)
12. [Troubleshooting](#troubleshooting)
13. [Customization](#customization)
14. [Security Features](#security-features)
15. [Cleanup](#cleanup)

---

## Project Overview

This Terraform configuration deploys a highly available, secure web application infrastructure on AWS, replicating the AWS Academy Cloud Architecting Capstone Project. It automates the deployment of a complete social research data platform with the **actual PHP application from the AWS Academy lab**.

### What's Included

- **Complete Infrastructure**: VPC, subnets, ALB, Auto Scaling, RDS, NAT Gateway
- **Authentic PHP Application**: 5 query types for country data analysis
- **Real Database**: 227 countries with comprehensive statistics
- **Security Best Practices**: Private subnets, Secrets Manager, least-privilege access
- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Infrastructure as Code**: Everything version-controlled and repeatable

### Key Features

✅ **High Availability** - Multi-AZ deployment across 2 availability zones
✅ **Security** - Private subnets for web/DB, security groups, Secrets Manager
✅ **Scalability** - Auto Scaling Group with CPU-based scaling policy
✅ **Load Balancing** - Application Load Balancer distributes traffic
✅ **Infrastructure as Code** - Everything defined in code, version controlled
✅ **Secrets Management** - No hardcoded passwords, uses AWS Secrets Manager
✅ **Best Practices** - Follows AWS Well-Architected Framework principles

---

## Architecture

### Architecture Diagram

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
```

### Infrastructure Components

#### Networking (11 resources)
- 1 VPC (10.0.0.0/16)
- 2 Public Subnets (for ALB)
- 2 Private Subnets (for EC2 web servers)
- 2 Database Subnets (for RDS)
- 1 Internet Gateway
- 1 NAT Gateway + Elastic IP
- 2 Route Tables + 4 Associations

#### Security (3 resources)
- ALB Security Group (allow HTTP from internet)
- Web Server Security Group (allow HTTP from ALB only)
- RDS Security Group (allow MySQL from web servers only)

#### Compute & Load Balancing (6 resources)
- Application Load Balancer
- Target Group
- ALB Listener
- Launch Template
- Auto Scaling Group (2-4 instances)
- Auto Scaling Policy (CPU-based)

#### Database & Secrets (4 resources)
- RDS MySQL Instance (db.t3.micro)
- DB Subnet Group
- Secrets Manager Secret (stores DB credentials)
- Random Password Generator

#### IAM (3 resources)
- EC2 IAM Role
- IAM Policy (Secrets Manager access)
- IAM Instance Profile

**Total: ~31 AWS resources**

---

## Files & Structure

### Project Structure

```
aws-capstone-terraform/
├── main.tf              # All infrastructure resources
├── provider.tf          # AWS provider configuration
├── variables.tf         # Variable definitions
├── terraform.tfvars     # Variable values (customize this)
├── outputs.tf           # Output definitions
├── data.tf              # Data sources (AMI lookup, AZ discovery)
├── user-data.sh         # EC2 initialization script with PHP app
├── countries.sql        # Database dump (227 countries)
├── Logo.png             # Organization logo
├── Shirley.jpeg         # Researcher photo
├── .gitignore           # Git ignore rules
└── Documentation/
    ├── README.md                    # Main documentation
    ├── QUICKSTART.md                # Quick start guide
    ├── PROJECT_SUMMARY.md           # Project overview
    ├── CHECKLIST.md                 # Getting started checklist
    ├── DATABASE_IMPORT.md           # Database import guide
    ├── UPDATE_SUMMARY.md            # Update history
    ├── IMAGES_SETUP.md              # Image deployment guide
    └── FINAL_UPDATE.md              # Latest changes
```

### Core Terraform Files

1. **main.tf** - All infrastructure resources (VPC, subnets, RDS, ALB, Auto Scaling, etc.)
2. **provider.tf** - AWS provider configuration
3. **variables.tf** - Variable definitions (customizable parameters)
4. **terraform.tfvars** - Variable values (edit these to customize)
5. **outputs.tf** - Output values (ALB URL, RDS endpoint, etc.)
6. **data.tf** - Data sources (AMI lookup, AZ discovery)

### Supporting Files

7. **user-data.sh** - EC2 initialization script (installs Apache, PHP, Composer, AWS SDK)
8. **countries.sql** - Your actual 227-country database dump
9. **Logo.png** - Organization logo image
10. **Shirley.jpeg** - Researcher photo
11. **.gitignore** - Excludes sensitive files from Git

### PHP Application Files (Created by user-data.sh)

1. `index.php` - Homepage with navigation
2. `query.php` - Query selection page
3. `query2.php` - Query router
4. `get-parameters.php` - Secrets Manager integration
5. `mobile.php` - Mobile phones query
6. `population.php` - Population query
7. `lifeexpectancy.php` - Life expectancy query
8. `gdp.php` - GDP query
9. `mortality.php` - Mortality query
10. `aws-autoloader.php` - AWS SDK loader
11. `composer.json` - PHP dependencies

---

## Prerequisites

### Required Software

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (version >= 1.0)
   - macOS: `brew install terraform`
   - Windows: Download from https://www.terraform.io/downloads
   - Linux: `sudo apt-get install terraform`
3. **AWS CLI** configured with credentials
4. **MySQL Client** (for database import)
5. **jq** (for parsing JSON)

### AWS Credentials Setup

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json
```

### Verify AWS Access

```bash
aws sts get-caller-identity
```

---

## Quick Start Guide

### 6-Step Quick Deploy

#### Step 1: Configure AWS Credentials
```bash
aws configure
```

#### Step 2: Upload PHP Application to S3
```bash
cd aws-capstone-terraform

# Make script executable
chmod +x upload-to-s3.sh

# Upload PHP files to S3
./upload-to-s3.sh
```

This script will:
- Create a new S3 bucket with a unique name
- Upload all PHP files and images from `php-app/` directory
- Enable versioning on the bucket
- Automatically update `terraform.tfvars` with the bucket name

**Wait for confirmation before proceeding.**

#### Step 3: Initialize Terraform
```bash
terraform init
```
Expected output: "Terraform has been successfully initialized!"

#### Step 4: Deploy Infrastructure (15 minutes)
```bash
terraform apply
```
- Review the plan (shows ~31 resources)
- Type `yes` when prompted
- Wait 10-15 minutes for completion
- EC2 instances will automatically download PHP files from S3

#### Step 5: Get Your Application URL
```bash
terraform output alb_url
```
Copy the URL (looks like: http://capstone-alb-1234567890.us-east-1.elb.amazonaws.com)

#### Step 6: Import Database Data
```bash
# Get endpoint
RDS_HOST=$(terraform output -raw rds_address)

# Get password
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

# Import data
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

---

## Detailed Deployment

### Phase 1: Pre-Deployment (5 minutes)

#### 1.1 Open Terminal/Command Prompt
Navigate to the project folder:
```bash
cd aws-capstone-terraform
```

#### 1.2 Review Configuration
Edit `terraform.tfvars` if you want to customize:
- AWS region
- Instance types
- Auto Scaling group sizes
- Database configurations

#### 1.3 Verify Prerequisites
```bash
# Check Terraform version
terraform --version

# Check AWS credentials
aws sts get-caller-identity

# Check for required files
ls -la
```

### Phase 2: Terraform Initialization (1 minute)

```bash
terraform init
```

This downloads the required provider plugins. You should see:
```
Terraform has been successfully initialized!
```

### Phase 3: Preview Changes (2 minutes)

```bash
terraform plan
```

Review the output showing ~31 resources to be created:
- VPC and networking components
- Security groups
- RDS instance
- Load balancer
- Auto Scaling group

### Phase 4: Deploy Infrastructure (15 minutes)

```bash
terraform apply
```

- Type `yes` when prompted
- Wait patiently (RDS takes longest ~10 minutes)
- Note the outputs when complete

**Expected outputs:**
- `alb_url` - Your application URL
- `rds_endpoint` - Database endpoint
- `secrets_manager_secret_arn` - ARN of the database credentials

### Phase 5: Handle Images (5 minutes)

**Option A: Upload to S3 (Recommended)**

```bash
# Create bucket
BUCKET_NAME="capstone-assets-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Upload images
aws s3 cp Logo.png s3://$BUCKET_NAME/
aws s3 cp Shirley.jpeg s3://$BUCKET_NAME/

# Make public
aws s3api put-object-acl --bucket $BUCKET_NAME --key Logo.png --acl public-read
aws s3api put-object-acl --bucket $BUCKET_NAME --key Shirley.jpeg --acl public-read

# Add to user-data.sh (before "Set proper permissions"):
# aws s3 cp s3://$BUCKET_NAME/Logo.png /var/www/html/Logo.png
# aws s3 cp s3://$BUCKET_NAME/Shirley.jpeg /var/www/html/Shirley.jpeg
```

**Option B: Custom AMI**
See IMAGES_SETUP section for detailed instructions.

**Option C: Base64 Encode**
Encode images directly in user-data.sh (increases script size).

### Phase 6: Verify Deployment (3 minutes)

```bash
# Get ALB URL
terraform output alb_url

# Open in browser
# Should see application homepage
# May show "Database connection failed" initially (expected - data not imported yet)
```

---

## Database Import

### Your Database Schema

**Database Details:**
- **Database Name:** `country_schema`
- **Table Name:** `countrydata_final`
- **Records:** 227 countries
- **Columns:**
  - name (country name)
  - mobilephones
  - mortalityunder5
  - healthexpenditurepercapita
  - healthexpenditureppercentGDP
  - population
  - populationurban
  - birthrate
  - lifeexpectancy
  - GDP

### Import Methods

#### Method 1: From Local Machine (Recommended)

**Prerequisites:**
- MySQL client installed on your computer
- Your AWS infrastructure deployed

**Steps:**

1. **Get Database Endpoint:**
```bash
terraform output rds_address
```
Example output: `capstone-mysql-db.abc123.us-east-1.rds.amazonaws.com`

2. **Get Database Password:**
```bash
aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password'
```

3. **Import the Data:**
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema < countries.sql
```
When prompted, paste the password from step 2.

**Expected Output:**
```
(Takes 10-30 seconds to complete)
```

4. **Verify Import:**
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema -e "SELECT COUNT(*) FROM countrydata_final;"
```
Should show: 227 rows

#### Method 2: From EC2 Instance via Session Manager

**Steps:**

1. **Go to AWS Console → EC2 → Instances**

2. **Select one of your `capstone-web-server` instances**

3. **Click "Connect" → "Session Manager" → "Connect"**

4. **In the terminal, run:**
```bash
# Install jq if not present
sudo yum install -y jq

# Get database credentials
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text)

DB_HOST=$(echo $SECRET | jq -r '.host')
DB_USER=$(echo $SECRET | jq -r '.username')
DB_PASS=$(echo $SECRET | jq -r '.password')

# Upload SQL file to S3 first, then:
aws s3 cp s3://your-bucket/countries.sql /tmp/countries.sql

# Import the data
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS country_schema < /tmp/countries.sql

# Verify
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS country_schema -e "SELECT COUNT(*) FROM countrydata_final;"
```

#### Method 3: Using MySQL Workbench (GUI)

1. **Download MySQL Workbench** (if not installed)
2. **Create New Connection:**
   - Hostname: `<your-rds-endpoint>`
   - Port: `3306`
   - Username: `admin`
   - Password: `<from secrets manager>`
   - Default Schema: `country_schema`
3. **Click "Test Connection"**
4. **Open the connection**
5. **File → Run SQL Script → Select `countries.sql`**
6. **Click "Run"**

### Verification Steps

#### 1. Check Table Exists
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema -e "SHOW TABLES;"
```
Should show: `countrydata_final`

#### 2. Check Row Count
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema -e "SELECT COUNT(*) FROM countrydata_final;"
```
Should show: 227

#### 3. Check Sample Data
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema -e "SELECT name, population, lifeexpectancy FROM countrydata_final LIMIT 5;"
```

#### 4. Test Web Application
1. Open your ALB URL in browser
2. Search for "United States"
3. Should see data with:
   - Population: 282,162,411
   - Life Expectancy: 77 years
   - GDP: $9,898,800,000,000

### Quick Import Script

Save this as `import.sh`:

```bash
#!/bin/bash

# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_address)

# Get database password
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

# Import data
echo "Importing data to $RDS_ENDPOINT..."
mysql -h $RDS_ENDPOINT -u admin -p$DB_PASSWORD country_schema < countries.sql

# Verify
echo "Verifying import..."
mysql -h $RDS_ENDPOINT -u admin -p$DB_PASSWORD country_schema -e "SELECT COUNT(*) as 'Total Countries' FROM countrydata_final;"

echo "Sample data:"
mysql -h $RDS_ENDPOINT -u admin -p$DB_PASSWORD country_schema -e "SELECT name, population, lifeexpectancy FROM countrydata_final LIMIT 3;"

echo "Import complete!"
```

Make it executable and run:
```bash
chmod +x import.sh
./import.sh
```

---

## PHP Application and Image Files Setup

The PHP application and image files (Logo.png and Shirley.jpeg) are now managed together using the **upload-to-s3.sh** script.

### Simplified Approach

**All application files, including images, are uploaded to S3 in one step:**

```bash
# Make the script executable
chmod +x upload-to-s3.sh

# Upload all PHP files and images to S3
./upload-to-s3.sh
```

This single script:
- Creates a new S3 bucket with a unique name
- Uploads all PHP files from `php-app/` directory
- Uploads both image files (Logo.png and Shirley.jpeg)
- Enables versioning on the bucket
- Automatically updates `terraform.tfvars` with the bucket name
- Saves the bucket name to `.s3-bucket-name` for reference

### What Happens During Deployment

When EC2 instances launch:
1. The `user-data.sh` script runs automatically
2. It downloads all files from S3 using `aws s3 sync`
3. All PHP files are placed in `/var/www/html/`
4. All image files are included automatically
5. No separate image upload step needed!

### Benefits of This Approach

✅ **Single upload process** - One command uploads everything
✅ **Version controlled** - S3 versioning enabled by default
✅ **Easy updates** - Just run the script again to update files
✅ **No duplication** - Uses actual files from `php-app/` directory
✅ **Automatic deployment** - EC2 instances get latest files on launch

### Manual File Updates (Optional)

If you need to update specific files without redeploying:

```bash
# Get your bucket name
BUCKET_NAME=$(cat .s3-bucket-name)

# Upload a single updated file
aws s3 cp php-app/index.php s3://$BUCKET_NAME/php-app/index.php

# Or sync entire directory
aws s3 sync php-app/ s3://$BUCKET_NAME/php-app/
```

Then restart your EC2 instances or update the launch template to pull new files.

---

## PHP Application Details

### Application Overview

The **Example Social Research Organization** website provides comprehensive query capabilities for country data analysis.

### Query Types Available

Users can query by:

1. **Mobile Phones** - Mobile phone subscribers by country
2. **Population** - Total and urban population
3. **Life Expectancy** - Life expectancy rankings
4. **GDP** - Economic data by country
5. **Childhood Mortality** - Mortality rates under age 5

### Application Pages

#### Homepage (index.php)
- Header: "Example Social Research Organization"
- Navigation: About Us, Contact Us, Query
- Welcome message
- About Shirley Rodriguez section with photo
- Contact information with logo
- Professional styling

#### Query Page (query.php)
- Dropdown menu with 5 query options
- Submit button to execute query
- Navigation back to homepage

#### Query Results Pages
- Full table of ALL countries sorted by selected metric
- Professional data presentation
- Formatted numbers with commas
- "Pick another query" link to go back

### Sample Query Results

#### Mobile Phones Query
Shows countries ranked by mobile phone subscribers:
- United States: 109,478,031
- Japan: 66,784,374
- China: 85,260,000

#### Population Query
Shows total and urban population:
- China: 1,439,323,776 total
- India: 1,380,004,385 total
- United States: 282,162,411 total

#### Life Expectancy Query
Sorted by longest to shortest:
- Japan: 82 years
- Switzerland: 80 years
- Iceland: 80 years

#### GDP Query
Economic rankings:
- United States: $9,898,800,000,000
- Japan: $4,731,200,000,000
- Germany: $1,886,400,000,000

#### Childhood Mortality Query
Mortality rates under age 5:
- Shows countries from highest to lowest mortality
- Important development statistics

### AWS SDK PHP Integration

The application uses AWS SDK for PHP to:
- Detect EC2 region automatically
- Query Secrets Manager for RDS credentials
- Follow AWS security best practices

### Secrets Manager Format

The app expects this format (auto-created by Terraform):
```json
{
  "username": "admin",
  "password": "your-password",
  "host": "rds-endpoint.amazonaws.com",
  "dbname": "country_schema"
}
```

### Styling Features

The application includes:
- Responsive design
- Professional color scheme (#2c3e50, #1abc9c)
- Hover effects on navigation
- Formatted numbers with commas
- Clean table layouts
- Mobile-friendly (responsive)

---

## Testing & Verification

### Complete Testing Checklist

#### Infrastructure Tests
- [ ] `terraform apply` completes without errors
- [ ] All 31 resources created successfully
- [ ] No error messages in Terraform output

#### Network Tests
- [ ] ALB URL accessible from browser
- [ ] Health checks passing in target group
- [ ] Auto Scaling Group shows 2 healthy instances
- [ ] EC2 instances in private subnets (no public IPs)
- [ ] RDS in database subnets

#### Application Tests
- [ ] Homepage loads with proper styling
- [ ] Can navigate to "About Us" section
- [ ] Can see Shirley's photo (if images deployed)
- [ ] Can see organization logo (if images deployed)
- [ ] Query page has dropdown with 5 options

#### Database Tests
- [ ] Database connection shows "successful"
- [ ] Mobile Phones query shows all 227 countries
- [ ] Population query displays total and urban population
- [ ] Life Expectancy query shows sorted data
- [ ] GDP query displays economic data
- [ ] Childhood Mortality query works
- [ ] All tables are formatted properly
- [ ] Can navigate back to query selection

#### Security Tests
- [ ] Database credentials in Secrets Manager
- [ ] No hardcoded passwords in code
- [ ] Security groups properly configured
- [ ] EC2 instances have IAM role for Secrets Manager
- [ ] RDS not publicly accessible

### Testing Commands

#### Check Auto Scaling Group
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg
```

#### Check RDS Status
```bash
aws rds describe-db-instances \
  --db-instance-identifier capstone-mysql-db
```

#### Check ALB Targets
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

#### View EC2 Instance Logs
```bash
# Connect via Session Manager, then:
sudo tail -f /var/log/cloud-init-output.log
```

### Test Countries to Search

Try searching for these countries:
1. **United States** - Large economy
2. **China** - Largest population
3. **Monaco** - Small country
4. **Brazil** - South America
5. **Germany** - Europe
6. **Japan** - Asia

All should return comprehensive data with 10 fields!

---

## Cost Management

### Cost Estimate (us-east-1)

#### Hourly Costs
- NAT Gateway: $0.045/hour
- RDS db.t3.micro: $0.017/hour
- EC2 t2.micro (×2): $0.023/hour
- ALB: $0.0225/hour
- **Total: ~$0.11/hour**

#### Monthly Costs
- **Running 24/7: ~$80/month**
- **8 hours/day, 5 days/week: ~$20/month**

### Cost Optimization Tips

#### Option 1: Stop RDS When Not Using
```bash
# Stop RDS instance (will auto-restart after 7 days)
aws rds stop-db-instance --db-instance-identifier capstone-mysql-db

# Savings: ~$12/month
```

#### Option 2: Scale Down Auto Scaling Group
```bash
# Set Auto Scaling to 0 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 0

# Savings: ~$17/month
```

#### Option 3: Delete NAT Gateway (breaks private subnet internet)
```bash
# Note: Will prevent Composer downloads and updates
# Savings: ~$33/month
```

#### Option 4: Use terraform destroy When Done
```bash
terraform destroy
# Saves 100% of costs
```

### Budget Setup

**Set up budget alert:**
1. Go to AWS Billing Console
2. Create Budget
3. Set threshold (e.g., $50)
4. Add email notification

**Check current spend:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-28 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

### Cost Tracking Checklist

**While testing:**
- [ ] Set budget alert in AWS Console (recommended: $50)
- [ ] Monitor costs daily
- [ ] Review CloudWatch metrics

**When not using:**
- [ ] Stop RDS instance
- [ ] Scale Auto Scaling Group to 0

**When completely done:**
- [ ] Run `terraform destroy`
- [ ] Verify all resources deleted in AWS Console
- [ ] Check for any lingering resources (EIPs, snapshots)

---

## Troubleshooting

### Terraform Issues

#### Issue: terraform init fails
**Symptoms:** Error downloading provider plugins
**Solutions:**
- Check internet connection
- Verify Terraform is installed correctly
- Try `terraform init -upgrade`
- Clear `.terraform` directory and retry

#### Issue: terraform apply fails with permission error
**Symptoms:** "AccessDenied" errors
**Solutions:**
- Verify AWS credentials: `aws sts get-caller-identity`
- Check IAM permissions (need VPC, EC2, RDS, Secrets Manager, IAM)
- Ensure credentials are not expired

#### Issue: "Error: creating DB Instance: InvalidParameterValue"
**Solutions:**
- Make sure you're in a region with at least 2 Availability Zones
- Try `us-east-1` (recommended)
- Check RDS service quotas

### Application Issues

#### Issue: Web page won't load
**Solutions:**
- Wait 5 more minutes for health checks
- Check target group health in AWS Console
- Verify EC2 instances are running
- Check security groups allow HTTP from ALB
- Review EC2 instance logs

#### Issue: "Database connection failed"
**Solutions:**
- Wait 5 minutes for RDS initialization
- Verify security groups allow MySQL traffic
- Check Secrets Manager secret exists
- Verify database name is `country_schema`
- Check RDS endpoint is correct

#### Issue: Images don't show
**Solutions:**
- Follow IMAGES_SETUP.md to deploy images
- Check S3 bucket permissions
- Verify image paths in user-data.sh
- Check /var/www/html directory on EC2

#### Issue: "Class 'Aws\SecretsManager\SecretsManagerClient' not found"
**Solutions:**
- Composer didn't complete installation
- Check /var/log/cloud-init-output.log
- Verify NAT Gateway is running
- SSH to instance and run `composer install` manually

#### Issue: All queries show empty tables
**Solutions:**
- Database not imported yet
- Run the import command
- Verify table name is `countrydata_final`
- Check connection to RDS

### Database Issues

#### Issue: "Access denied for user"
**Solutions:**
- Verify correct password from Secrets Manager
- Check security group allows traffic from your IP or EC2 instance
- Ensure RDS is available (not stopped)

#### Issue: "Unknown database 'country_schema'"
**Solutions:**
```bash
mysql -h <RDS_ENDPOINT> -u admin -p -e "CREATE DATABASE country_schema;"
```

#### Issue: "Table 'countrydata_final' already exists"
**Solutions:**
```bash
mysql -h <RDS_ENDPOINT> -u admin -p country_schema -e "DROP TABLE countrydata_final;"
mysql -h <RDS_ENDPOINT> -u admin -p country_schema < countries.sql
```

#### Issue: Import is very slow
**Solutions:**
- Normal for 227 rows with large values
- Should complete in under 1 minute
- Check network connectivity
- Verify RDS instance size

#### Issue: Cannot connect to RDS from local machine
**Note:** Your RDS is in private subnets (security best practice)
**Solutions:**
1. Use EC2 Session Manager method
2. Temporarily modify RDS security group to allow your IP
3. Set up a bastion host

### Monitoring Issues

#### Issue: "No healthy targets"
**Solutions:**
1. Wait 5 minutes for health checks
2. Check EC2 instances are running
3. Verify Apache is running on instances
4. Check security groups allow HTTP from ALB
5. Verify /health.txt exists

#### Issue: High costs
**Solutions:**
1. Stop RDS instance when not using
2. Scale Auto Scaling Group to 0
3. Delete NAT Gateway (breaks private subnet internet)
4. Run `terraform destroy` when done
5. Check for orphaned resources

### Common Error Messages

#### "Error: Error creating DB Instance: DBInstanceAlreadyExists"
**Solution:**
```bash
# Database from previous deployment still exists
terraform destroy
# Wait for deletion to complete
terraform apply
```

#### "Error: Error creating application Load Balancer: DuplicateLoadBalancer"
**Solution:**
```bash
# Clean up existing resources
terraform destroy
terraform apply
```

#### "Error: creating EC2 Instance: InsufficientInstanceCapacity"
**Solution:**
- AWS is out of capacity in that AZ
- Try different region
- Try different instance type

---

## Customization

### Changing Variables

Edit `terraform.tfvars` to customize:

#### Change Region
```hcl
aws_region = "us-west-2"
```

#### Change Instance Types
```hcl
instance_type = "t3.small"
db_instance_class = "db.t3.small"
```

#### Change Auto Scaling Sizes
```hcl
asg_min_size         = 3
asg_max_size         = 6
asg_desired_capacity = 3
```

#### Change Database Configuration
```hcl
db_allocated_storage = 30
db_name             = "my_database"
db_username         = "dbadmin"
```

Then run:
```bash
terraform apply
```

### Modifying the Application

#### Update PHP Code
Edit the PHP sections in `user-data.sh`, then:
```bash
terraform apply -replace="aws_launch_template.web"
```

#### Add New Query Type
1. Add new PHP file in user-data.sh
2. Update query.php to include new option
3. Update query2.php to route to new file
4. Redeploy instances

#### Change Styling
Edit CSS in the PHP files within user-data.sh

### Advanced Modifications

#### Add HTTPS Support
1. Create ACM certificate
2. Update ALB listener in main.tf
3. Add port 443 to security groups

#### Add Bastion Host
1. Create bastion instance in public subnet
2. Add security group for SSH access
3. Use for database administration

#### Add CloudWatch Monitoring
1. Enable detailed monitoring in launch template
2. Create CloudWatch alarms for metrics
3. Set up SNS notifications

#### Implement Database Backups
1. Enable automated backups in RDS
2. Set backup retention period
3. Create manual snapshots before changes

---

## Security Features

### Network Security

✅ **Private Subnets for Web Servers**
- EC2 instances have no direct internet access
- All traffic routed through NAT Gateway
- No public IP addresses assigned

✅ **Isolated Database Subnets**
- RDS in separate subnet tier
- Not publicly accessible
- Only accessible from web server security group

✅ **Security Groups with Least Privilege**
- ALB: Allow HTTP (80) from internet
- Web: Allow HTTP (80) from ALB only
- RDS: Allow MySQL (3306) from web servers only

### Application Security

✅ **Secrets Manager for Credentials**
- No hardcoded passwords
- Automatic password generation
- Encrypted at rest and in transit

✅ **IAM Roles for EC2**
- Minimal required permissions
- No access keys on instances
- Secrets Manager read-only access

✅ **Prepared SQL Statements**
- Protection against SQL injection
- Parameterized queries in PHP

### Infrastructure Security

✅ **Application Load Balancer**
- Shields backend servers
- SSL/TLS termination ready
- Health checks for availability

✅ **Auto Scaling**
- Automatic instance replacement
- Maintains desired capacity
- Self-healing infrastructure

✅ **Multi-AZ Deployment**
- High availability
- Fault tolerance
- Disaster recovery ready

### Best Practices Implemented

✅ **Infrastructure as Code**
- Version controlled
- Auditable changes
- Reproducible deployments

✅ **Least Privilege Access**
- Minimal IAM permissions
- Restrictive security groups
- Private by default

✅ **Data Encryption**
- Secrets encrypted in Secrets Manager
- RDS supports encryption at rest (can be enabled)
- HTTPS ready (ALB supports SSL)

---

## Cleanup

### Complete Cleanup Process

#### Step 1: Backup Any Important Data
```bash
# Backup database
mysqldump -h <RDS_ENDPOINT> -u admin -p country_schema > backup.sql

# Save Terraform state (optional)
terraform state pull > terraform-state-backup.json
```

#### Step 2: Destroy Infrastructure
```bash
terraform destroy
```
- Type `yes` to confirm
- Wait for all resources to be deleted (5-10 minutes)

#### Step 3: Verify Deletion

**Check in AWS Console:**
- [ ] No EC2 instances running
- [ ] No RDS instances
- [ ] No Load Balancers
- [ ] No NAT Gateways
- [ ] No Elastic IPs
- [ ] No VPCs (the capstone VPC)

**Check via CLI:**
```bash
# Check EC2 instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=capstone-*"

# Check RDS instances
aws rds describe-db-instances --db-instance-identifier capstone-mysql-db

# Check Load Balancers
aws elbv2 describe-load-balancers --names capstone-alb
```

#### Step 4: Clean Up S3 (if used for images)
```bash
# List buckets
aws s3 ls

# Delete bucket and contents
aws s3 rb s3://your-bucket-name --force
```

#### Step 5: Clean Up Secrets Manager
```bash
# Delete secret (with recovery window)
aws secretsmanager delete-secret \
  --secret-id capstone-db-credentials \
  --recovery-window-in-days 7

# Force delete (no recovery)
aws secretsmanager delete-secret \
  --secret-id capstone-db-credentials \
  --force-delete-without-recovery
```

#### Step 6: Local Cleanup
```bash
# Remove Terraform state files
rm -rf .terraform
rm terraform.tfstate*

# Keep the .tf files for future use
```

### Partial Cleanup (Keep Infrastructure, Stop Costs)

If you want to keep the infrastructure but minimize costs:

```bash
# Stop RDS
aws rds stop-db-instance --db-instance-identifier capstone-mysql-db

# Scale ASG to 0
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 0 \
  --no-honor-cooldown
```

**Note:** NAT Gateway cannot be stopped, only deleted. Consider full cleanup to avoid NAT Gateway charges.

### Cleanup Verification Checklist

- [ ] All EC2 instances terminated
- [ ] RDS instance deleted
- [ ] Load Balancer deleted
- [ ] NAT Gateway deleted
- [ ] Elastic IP released
- [ ] VPC deleted
- [ ] Security Groups deleted
- [ ] Secrets Manager secret deleted
- [ ] S3 bucket deleted (if created)
- [ ] No orphaned EBS volumes
- [ ] No CloudWatch alarms remaining
- [ ] Billing alerts show $0/day

### Important Warnings

⚠️ **Terraform destroy is irreversible!**
- All data will be permanently deleted
- Make backups before destroying
- No recovery after deletion

⚠️ **Check for orphaned resources**
- EBS snapshots
- Elastic IPs not released
- S3 buckets
- CloudWatch log groups

⚠️ **Monitor billing for 24 hours**
- Ensure all resources deleted
- Check for unexpected charges
- Verify $0/day in cost explorer

---

## Additional Resources

### Documentation Links

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [PHP MySQL Documentation](https://www.php.net/manual/en/book.mysqli.php)
- [AWS SDK for PHP](https://aws.amazon.com/sdk-for-php/)

### Useful Commands Reference

#### Terraform Commands
```bash
terraform init          # Initialize project
terraform plan          # Preview changes
terraform apply         # Deploy infrastructure
terraform destroy       # Delete everything
terraform output        # Show outputs
terraform show          # Show current state
terraform validate      # Validate configuration
terraform fmt           # Format code
```

#### AWS CLI Commands
```bash
# Get outputs
terraform output alb_url
terraform output rds_address

# Check resources
aws ec2 describe-instances
aws rds describe-db-instances
aws elbv2 describe-load-balancers
aws autoscaling describe-auto-scaling-groups

# Get secrets
aws secretsmanager get-secret-value --secret-id capstone-db-credentials

# Check costs
aws ce get-cost-and-usage --time-period Start=2025-10-01,End=2025-10-28 --granularity MONTHLY --metrics "UnblendedCost"
```

### Next Steps & Enhancements

#### Immediate Next Steps
1. Review this documentation thoroughly
2. Customize terraform.tfvars for your preferences
3. Deploy the infrastructure
4. Import your database
5. Test all query types

#### Advanced Enhancements
1. **Add HTTPS** - Create ACM certificate and update ALB listener
2. **CloudWatch Monitoring** - Set up detailed monitoring and alarms
3. **CI/CD Pipeline** - Automate deployments with GitHub Actions
4. **Bastion Host** - Add secure SSH access for administration
5. **Database Backups** - Implement automated backup strategy
6. **WAF** - Add Web Application Firewall for security
7. **CloudFront** - Add CDN for better performance
8. **Multi-Region** - Replicate in another region for DR
9. **Route53** - Add custom domain name
10. **ElastiCache** - Add Redis/Memcached for caching

---

## Summary

You now have a **complete, production-ready Terraform configuration** that:

✅ Replicates the AWS Academy Capstone Project
✅ Deploys authentic PHP application from the lab
✅ Includes your actual 227-country database
✅ Follows infrastructure-as-code best practices
✅ Implements AWS security best practices
✅ Provides high availability and auto-scaling
✅ Can be deployed in minutes
✅ Is fully customizable
✅ Includes comprehensive documentation

### Success Criteria

Your deployment is successful when:
- [ ] `terraform apply` completes without errors
- [ ] Can access ALB URL in browser
- [ ] Homepage loads with all sections
- [ ] Images display (Logo and Shirley)
- [ ] All 5 query types work
- [ ] Each query shows 227 countries
- [ ] Data is properly formatted
- [ ] Database connection successful
- [ ] Auto Scaling Group has 2 healthy instances
- [ ] All security groups properly configured
- [ ] No resources exposed to public internet except ALB

### Final Notes

⚠️ **This infrastructure costs money** - Budget ~$2-3/day if running 24/7
⚠️ **Don't commit secrets** - .gitignore configured but be careful
⚠️ **Destroy when done** - Run `terraform destroy` to avoid charges
✅ **Use version control** - Commit your .tf files to Git
✅ **Document changes** - Keep notes on modifications
✅ **Monitor costs** - Set up AWS Budget alerts

---

## License & Attribution

This project is for educational purposes as part of the AWS Academy Cloud Architecting course.

**Created:** October 2025
**Updated:** October 2025
**Version:** 1.0

---

## Getting Help

If you encounter issues:
1. Review the Troubleshooting section
2. Check AWS Console for resource status
3. Review CloudWatch logs
4. Verify AWS credentials are configured correctly
5. Ensure you're using a supported region (us-east-1 recommended)
6. Check AWS service quotas

---

## Acknowledgments

- AWS Academy Cloud Architecting Capstone Project
- Terraform AWS Provider
- AWS SDK for PHP
- MySQL Community

---

**You're ready to deploy! Simply run `terraform apply` and your entire infrastructure will be created automatically!** 🚀
