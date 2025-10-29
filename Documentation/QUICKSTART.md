# Quick Start Deployment Guide

## Step-by-Step Instructions

### 1. Prerequisites Setup

**Install Terraform:**
- macOS: `brew install terraform`
- Windows: Download from https://www.terraform.io/downloads
- Linux: `sudo apt-get install terraform`

**Configure AWS CLI:**
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json
```

### 2. Upload PHP Application to S3

**IMPORTANT FIRST STEP:** Upload your PHP application files to S3:

```bash
cd aws-capstone-terraform

# Make the script executable
chmod +x upload-to-s3.sh

# Run the upload script
./upload-to-s3.sh
```

This will:
- Create a new S3 bucket
- Upload all PHP files and images
- Automatically update terraform.tfvars with the bucket name

**Wait for confirmation** before proceeding to the next step.

### 3. Deploy Infrastructure

**Initialize Terraform:**
```bash
terraform init
```
Expected output: "Terraform has been successfully initialized!"

**Preview changes:**
```bash
terraform plan
```
Review the 40+ resources that will be created.

**Deploy infrastructure:**
```bash
terraform apply
```
- Review the plan
- Type `yes` when prompted
- Wait 10-15 minutes for completion
- EC2 instances will automatically download PHP files from S3

### 4. Get Your Application URL

**View outputs:**
```bash
terraform output alb_url
```

Copy the URL (looks like: http://capstone-alb-1234567890.us-east-1.elb.amazonaws.com)

### 5. Import Database Data

**Quick import from your local machine:**

```bash
# Get RDS endpoint
RDS_HOST=$(terraform output -raw rds_address)

# Get database password
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

# Import data
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

**Option B: From EC2 Instance (via Session Manager)**

1. Go to EC2 Console
2. Find one of your capstone-web-server instances
3. Click "Connect" → "Session Manager" → "Connect"
4. In the terminal:
```bash
# The SQL file should already be on the instance from user-data
# Or upload it using:
aws s3 cp s3://your-bucket/countries.sql /tmp/countries.sql

# Get credentials
SECRET=$(aws secretsmanager get-secret-value --secret-id capstone-db-credentials --region us-east-1 --query SecretString --output text)
DB_HOST=$(echo $SECRET | jq -r '.host')
DB_USER=$(echo $SECRET | jq -r '.username')
DB_PASS=$(echo $SECRET | jq -r '.password')

# Import data
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS countries < /tmp/countries.sql
```

### 6. Test Your Application

1. Open the ALB URL in your browser
2. You should see "Example Social Research Organization" homepage with:
   - Navigation menu (About Us, Contact Us, Query)
   - Logo and organization branding
   - Information about Shirley Rodriguez
3. Click "Query" to access the data query interface
4. Select a query type (Mobile phones, Population, GDP, etc.)
5. Verify you see results with all 227 countries

### 7. Monitor Your Resources

**Check Auto Scaling Group:**
```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names capstone-asg
```

**Check RDS Status:**
```bash
aws rds describe-db-instances \
  --db-instance-identifier capstone-mysql-db
```

**Check ALB Targets:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw aws_lb_target_group.main.arn)
```

### 8. Stopping Resources (to save money)

**Stop RDS (when not using):**
```bash
aws rds stop-db-instance --db-instance-identifier capstone-mysql-db
```

**Scale down Auto Scaling Group:**
```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name capstone-asg \
  --desired-capacity 0
```

**Note:** NAT Gateway cannot be stopped, only deleted. Consider destroying everything when done testing.

### 9. Complete Cleanup

**When completely done:**

```bash
# Destroy infrastructure
terraform destroy
```
- Type `yes` to confirm
- Wait for all resources to be deleted

**Optional: Delete S3 bucket with PHP files:**
```bash
# Get bucket name
BUCKET_NAME=$(cat .s3-bucket-name)

# Delete bucket and all files
aws s3 rb s3://$BUCKET_NAME --force
```

## Common Issues and Solutions

### Issue: "Error: creating DB Instance: InvalidParameterValue"
**Solution:** Make sure you're in a region with at least 2 Availability Zones. Try `us-east-1`.

### Issue: Web page shows "Database connection failed"
**Solutions:**
1. Wait 5 minutes for RDS to fully initialize
2. Check security groups allow traffic
3. Verify Secrets Manager secret was created
4. Check EC2 instance logs: `sudo tail -f /var/log/cloud-init-output.log`

### Issue: "No healthy targets"
**Solutions:**
1. Wait 5 minutes for health checks
2. Check EC2 instances are running
3. Verify Apache is running on instances
4. Check security groups allow HTTP from ALB

### Issue: High costs
**Solutions:**
1. Stop RDS instance when not using
2. Scale Auto Scaling Group to 0
3. Delete NAT Gateway (breaks private subnet internet)
4. Run `terraform destroy` when done

## Cost Tracking

**Check your current spend:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-28 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

**Set up budget alert:**
1. Go to AWS Billing Console
2. Create Budget
3. Set threshold (e.g., $50)
4. Add email notification

## Next Steps

1. **Customize the application** - Modify PHP files in user-data.sh
2. **Add HTTPS** - Create ACM certificate and update ALB listener
3. **Add monitoring** - Set up CloudWatch alarms
4. **Multi-region** - Duplicate infrastructure in another region
5. **CI/CD** - Automate deployments with GitHub Actions

## Getting Help

- Review the main README.md for detailed documentation
- Check AWS Console for resource status
- Review Terraform documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- AWS Support: https://console.aws.amazon.com/support/

## Success Checklist

- [ ] Terraform apply completed successfully
- [ ] Can access ALB URL in browser
- [ ] Web page loads without errors
- [ ] Database connection shows "successful"
- [ ] Can import countries data
- [ ] Search functionality returns results
- [ ] Auto Scaling Group shows 2 healthy instances
- [ ] All security groups configured correctly
