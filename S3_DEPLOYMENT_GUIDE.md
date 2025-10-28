# S3-Based PHP Application Deployment Guide

## Overview

This project now uses **S3 to store and deploy the PHP application files**, providing a cleaner, more maintainable approach than embedding files in the user-data script.

## What Changed?

### Before (Old Approach)
- PHP application files were embedded as heredocs in `user-data.sh`
- Large, complex user-data script (800+ lines)
- Hard to update application code
- Duplication between `php-app/` directory and heredocs
- Only images extracted from `php-app/`

### After (New Approach - S3)
- PHP application files stored in S3 bucket
- Clean, simple user-data script (~265 lines)
- Easy to update - just upload to S3
- Single source of truth: `php-app/` directory
- All files (PHP + images) deployed together

## How It Works

### 1. Upload Phase (One Time)

```bash
./upload-to-s3.sh
```

**What happens:**
1. Creates S3 bucket with unique name (e.g., `capstone-php-app-1234567890`)
2. Uploads all files from `php-app/` directory:
   - index.php
   - query.php
   - query2.php
   - get-parameters.php
   - mobile.php
   - population.php
   - lifeexpectancy.php
   - gdp.php
   - mortality.php
   - Logo.png
   - Shirley.jpeg
   - style.css
   - (any other files in php-app/)
3. Enables S3 versioning
4. Updates `terraform.tfvars` with bucket name
5. Saves bucket name to `.s3-bucket-name`

### 2. Deployment Phase (Automatic)

When you run `terraform apply`:

1. **IAM Role Created** - EC2 instances get IAM role with S3 read permissions
2. **Launch Template** - Includes S3 bucket name in user-data variables
3. **EC2 Instances Launch** - User-data script runs:
   ```bash
   aws s3 sync s3://your-bucket/php-app/ /var/www/html/
   ```
4. **Files Downloaded** - All PHP files and images copied to web root
5. **Apache Started** - Web server serves the application

## File Structure

```
aws-capstone-terraform/
├── php-app/                    # SOURCE OF TRUTH
│   ├── index.php              # Homepage
│   ├── query.php              # Query selector
│   ├── query2.php             # Query router
│   ├── get-parameters.php     # Secrets Manager integration
│   ├── mobile.php             # Mobile phones query
│   ├── population.php         # Population query
│   ├── lifeexpectancy.php    # Life expectancy query
│   ├── gdp.php                # GDP query
│   ├── mortality.php          # Mortality query
│   ├── Logo.png               # Organization logo
│   ├── Shirley.jpeg           # Researcher photo
│   └── style.css              # Styles
│
├── upload-to-s3.sh            # Upload script
├── user-data.sh               # Downloads from S3
├── main.tf                    # Includes S3 IAM permissions
├── variables.tf               # Includes s3_php_app_bucket variable
└── terraform.tfvars           # Set by upload script

S3 Bucket (created by script):
└── php-app/
    ├── index.php
    ├── query.php
    ├── Logo.png
    └── (all files from local php-app/)
```

## Benefits

### 1. Maintainability
- **Single source of truth**: Edit files in `php-app/` directory
- **No duplication**: No need to copy code to user-data.sh
- **Easy updates**: Just upload to S3 and restart instances

### 2. Version Control
- **S3 versioning**: Track changes to application files
- **Git friendly**: Only actual PHP files in repo, not embedded

### 3. Scalability
- **Fast downloads**: S3 is highly available and fast
- **Multiple regions**: Can replicate bucket to other regions
- **CloudFront ready**: Can add CDN for even faster delivery

### 4. Flexibility
- **Update without redeployment**: Upload new files to S3
- **Rollback capability**: S3 versioning allows rollback
- **A/B testing**: Can use different buckets for testing

## IAM Permissions

The EC2 instances have an IAM role with this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket-name",
        "arn:aws:s3:::your-bucket-name/*"
      ]
    }
  ]
}
```

This allows:
- ✅ Read files from the bucket
- ✅ List bucket contents
- ❌ Cannot write or delete (security)

## Deployment Workflow

### Initial Deployment

```bash
# Step 1: Upload to S3
./upload-to-s3.sh

# Step 2: Deploy infrastructure
terraform init
terraform apply

# Step 3: Import database
mysql -h $(terraform output -raw rds_address) \
  -u admin -p$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --query SecretString --output text | jq -r '.password') \
  country_schema < countries.sql

# Step 4: Access application
open $(terraform output -raw alb_url)
```

### Updating Application Code

```bash
# Option 1: Upload entire directory
./upload-to-s3.sh

# Option 2: Upload specific file
BUCKET=$(cat .s3-bucket-name)
aws s3 cp php-app/index.php s3://$BUCKET/php-app/index.php

# Option 3: Sync directory
aws s3 sync php-app/ s3://$BUCKET/php-app/

# Then either:
# - Restart EC2 instances to pull new files
# - Or wait for Auto Scaling to replace instances
# - Or use Systems Manager to run update command
```

### Restarting Instances to Get Updates

```bash
# Get instance IDs
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=capstone-web-server" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text

# Restart instances (one at a time for zero downtime)
aws ec2 reboot-instances --instance-ids i-1234567890abcdef0

# Or use Auto Scaling to replace all
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name capstone-asg
```

## Troubleshooting

### Issue: Files not downloading from S3

**Check:**
1. Bucket name in terraform.tfvars
2. IAM role attached to instances
3. S3 permissions in IAM policy
4. NAT Gateway is running (for internet access)

**Debug:**
```bash
# SSH to instance (via Session Manager)
# Check user-data log
sudo cat /var/log/user-data.log

# Check S3 access
aws s3 ls s3://your-bucket-name/php-app/

# Manually download
aws s3 sync s3://your-bucket-name/php-app/ /var/www/html/
```

### Issue: Bucket not found

**Solution:**
```bash
# Verify bucket exists
aws s3 ls | grep capstone-php-app

# Check .s3-bucket-name file
cat .s3-bucket-name

# Re-run upload script if needed
./upload-to-s3.sh
```

### Issue: Old files showing on website

**Solution:**
```bash
# Upload new files
./upload-to-s3.sh

# Clear instance cache (restart Apache)
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=capstone-web-server" \
  --parameters 'commands=["sudo systemctl restart httpd"]'
```

## Cost Considerations

### S3 Storage Costs

- **Storage**: $0.023 per GB/month (first 50 TB)
- **Your app**: ~few KB = negligible cost (~$0.01/month)
- **Requests**: $0.0004 per 1,000 GET requests
- **Data transfer to EC2**: Free (same region)

### Example Monthly Cost

```
Storage: 0.01 GB × $0.023 = $0.0002
Versioning: 0.02 GB × $0.023 = $0.0005
Requests: 1,000 × $0.0004 = $0.40
-----------------------------------------
Total S3 cost: ~$0.40/month
```

**Much cheaper than alternatives:**
- ✅ S3: $0.40/month
- ❌ Custom AMI: $0.05/GB-month for snapshots
- ❌ EFS: $0.30/GB-month

## Security

### Best Practices Implemented

✅ **Least privilege IAM**: EC2 can only read from specific bucket
✅ **No public access**: Bucket not publicly accessible
✅ **Versioning enabled**: Track all changes
✅ **Encryption**: S3 server-side encryption (optional, can enable)
✅ **No secrets in S3**: Database credentials in Secrets Manager

### Additional Security (Optional)

```hcl
# Enable S3 encryption (add to main.tf if desired)
resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket" {
  bucket = var.s3_php_app_bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

## Comparison: Old vs New

| Aspect | Old (Heredocs) | New (S3) |
|--------|----------------|----------|
| **user-data.sh size** | ~800 lines | ~265 lines |
| **Maintainability** | Hard | Easy |
| **Updates** | Redeploy infrastructure | Upload to S3 |
| **Version control** | Embedded in script | S3 versioning |
| **Testing** | Requires full deploy | Upload to test bucket |
| **Rollback** | Revert Terraform | Use S3 version |
| **Cost** | $0 | ~$0.40/month |
| **Performance** | Slower (inline) | Faster (S3 sync) |
| **Scalability** | Limited | Excellent |

## Summary

The S3-based approach provides:
- ✅ **Simpler deployment**: One upload script handles everything
- ✅ **Easier maintenance**: Edit files locally, upload to S3
- ✅ **Better version control**: S3 versioning + Git
- ✅ **Faster updates**: No need to recreate infrastructure
- ✅ **Production ready**: Follows AWS best practices
- ✅ **Minimal cost**: ~$0.40/month for S3

This is how production applications typically deploy to AWS - storing assets in S3 and downloading them at instance launch.
