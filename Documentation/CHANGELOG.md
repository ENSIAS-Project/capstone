# Changelog - S3-Based Deployment Implementation

## Date: 2025-10-28

## Summary

Migrated from embedded heredoc approach to S3-based PHP application deployment for better maintainability, version control, and production-readiness.

---

## Changes Made

### 1. New Files Created

#### `upload-to-s3.sh` ⭐ NEW
- **Purpose**: Upload PHP application files and images to S3
- **Features**:
  - Creates unique S3 bucket with timestamp
  - Uploads all files from `php-app/` directory
  - Enables S3 versioning
  - Automatically updates `terraform.tfvars`
  - Saves bucket name to `.s3-bucket-name`
  - Color-coded output for user guidance
  - Interactive prompt to update terraform.tfvars
- **Usage**: `chmod +x upload-to-s3.sh && ./upload-to-s3.sh`

#### `S3_DEPLOYMENT_GUIDE.md` ⭐ NEW
- **Purpose**: Comprehensive guide to S3-based deployment
- **Content**:
  - How the new system works
  - Benefits over old approach
  - Deployment workflow
  - Troubleshooting guide
  - Cost analysis
  - Security considerations
  - Comparison table (old vs new)

#### `CHANGELOG.md` ⭐ NEW
- This file documenting all changes

### 2. Modified Files

#### `user-data.sh` 🔄 MAJOR REWRITE
**Before:**
- 800+ lines with embedded heredocs
- PHP code duplicated from `php-app/` directory
- Hard to maintain and update

**After:**
- ~265 lines, clean and focused
- Downloads files from S3 using `aws s3 sync`
- Variables for S3 bucket and region
- Better logging and error handling
- Verification of downloaded files
- Fallback error pages if S3 download fails

**Key Changes:**
```bash
# Now downloads from S3
aws s3 sync s3://$S3_BUCKET/php-app/ /var/www/html/ \
    --region $AWS_REGION \
    --exclude "*.md" \
    --exclude ".DS_Store"
```

#### `main.tf` 🔄 UPDATED
**Changes:**
1. **New IAM Policy for S3 Access:**
   ```hcl
   resource "aws_iam_role_policy" "s3_policy" {
     name = "capstone-s3-policy"
     role = aws_iam_role.ec2_role.id

     policy = jsonencode({
       # Allow S3 GetObject and ListBucket
     })
   }
   ```

2. **Updated Launch Template:**
   ```hcl
   user_data = base64encode(templatefile("${path.module}/user-data.sh", {
     s3_bucket_name = var.s3_php_app_bucket  # NEW
     aws_region     = var.aws_region
   }))
   ```

#### `variables.tf` 🔄 UPDATED
**Added:**
```hcl
variable "s3_php_app_bucket" {
  description = "S3 bucket name containing PHP application files"
  type        = string
  default     = ""
}
```

#### `terraform.tfvars` 🔄 UPDATED
**Added:**
```hcl
# S3 Configuration
# IMPORTANT: Upload PHP files to S3 first using: ./upload-to-s3.sh
# Then update this value with your bucket name
s3_php_app_bucket = ""  # Will be set by upload-to-s3.sh script
```

#### `README.md` 🔄 UPDATED
**Changes:**
1. Updated project structure to include `php-app/` directory
2. Added Step 2: "Upload PHP Application Files to S3"
3. Updated deployment steps numbering (now 9 steps instead of 8)
4. Added explanation of what happens during deployment
5. Mentioned IAM roles with S3 permissions

**New Section:**
```markdown
### 2. Upload PHP Application Files to S3

**IMPORTANT:** Before deploying infrastructure, upload the PHP application files to S3:

```bash
chmod +x upload-to-s3.sh
./upload-to-s3.sh
```
```

#### `QUICKSTART.md` 🔄 UPDATED
**Changes:**
1. Renumbered all steps (now 9 steps)
2. Added new Step 2: "Upload PHP Application to S3"
3. Updated Step 3 to mention automatic PHP file downloads
4. Updated cleanup section to include S3 bucket deletion

**New Step:**
```markdown
### 2. Upload PHP Application to S3

**IMPORTANT FIRST STEP:** Upload your PHP application files to S3:

```bash
chmod +x upload-to-s3.sh
./upload-to-s3.sh
```
```

#### `COMPLETE_DOCUMENTATION.md` 🔄 UPDATED
**Changes:**
1. Updated "Quick Start Guide" from 5-step to 6-step
2. Added Step 2: "Upload PHP Application to S3"
3. Rewrote "Image Files Setup" section → "PHP Application and Image Files Setup"
4. Removed complex multi-option image setup (now all in one S3 upload)
5. Added benefits of new approach
6. Added manual file update instructions

**Major Section Rewrite:**
- Old: "Image Files Setup" with 3 different options
- New: "PHP Application and Image Files Setup" with single unified approach

### 3. Files That Didn't Change

✅ `provider.tf` - No changes needed
✅ `data.tf` - No changes needed
✅ `outputs.tf` - No changes needed
✅ `countries.sql` - Database dump unchanged
✅ `php-app/*` - All PHP files and images unchanged (now source of truth)

---

## Architecture Changes

### Before (Heredoc Approach)

```
Deployment:
user-data.sh (800 lines with embedded PHP)
  ↓
Creates PHP files inline with cat << EOF
  ↓
EC2 instances launch with embedded code
```

**Issues:**
- ❌ Duplication between `php-app/` and heredocs
- ❌ Hard to update application
- ❌ Large, complex user-data script
- ❌ Only images extracted from `php-app/`

### After (S3 Approach)

```
Deployment:
php-app/ (local directory)
  ↓
upload-to-s3.sh uploads to S3
  ↓
S3 Bucket stores files with versioning
  ↓
user-data.sh downloads via aws s3 sync
  ↓
EC2 instances get latest files
```

**Benefits:**
- ✅ Single source of truth: `php-app/` directory
- ✅ Easy updates: upload to S3
- ✅ Clean, simple user-data script
- ✅ S3 versioning for rollback
- ✅ Production-ready approach

---

## Deployment Workflow Changes

### Old Workflow

```bash
1. terraform init
2. terraform apply          # Long user-data script executes
3. Import database
4. Access application
```

### New Workflow

```bash
1. ./upload-to-s3.sh        # ⭐ NEW STEP
2. terraform init
3. terraform apply          # Downloads from S3
4. Import database
5. Access application
```

---

## IAM Permissions Added

New IAM policy for EC2 instances:

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
        "arn:aws:s3:::${bucket_name}",
        "arn:aws:s3:::${bucket_name}/*"
      ]
    }
  ]
}
```

**Security:**
- ✅ Read-only access
- ✅ Limited to specific bucket
- ✅ No write or delete permissions

---

## Cost Impact

### New Costs (S3)

- **Storage**: ~$0.0002/month (few KB)
- **Versioning**: ~$0.0005/month
- **Requests**: ~$0.40/month
- **Data transfer to EC2**: $0 (same region)

**Total: ~$0.40/month**

### Total Infrastructure Cost

| Resource | Monthly Cost |
|----------|-------------|
| NAT Gateway | ~$33 |
| RDS db.t3.micro | ~$12 |
| EC2 t2.micro (×2) | ~$17 |
| ALB | ~$16 |
| **S3 (NEW)** | **~$0.40** |
| **Total** | **~$78.40** |

**Impact: Negligible (~0.5% increase)**

---

## Testing Checklist

After implementing these changes, verify:

- [ ] `upload-to-s3.sh` creates bucket and uploads files
- [ ] terraform.tfvars updated with bucket name
- [ ] `.s3-bucket-name` file created
- [ ] `terraform init` succeeds
- [ ] `terraform plan` shows S3 IAM policy
- [ ] `terraform apply` completes successfully
- [ ] EC2 instances download files from S3
- [ ] PHP files present in `/var/www/html/`
- [ ] Images (Logo.png, Shirley.jpeg) present
- [ ] Application loads in browser
- [ ] All 5 query types work
- [ ] Database connection successful

### Verification Commands

```bash
# Check S3 bucket
aws s3 ls s3://$(cat .s3-bucket-name)/php-app/

# Check EC2 instance (via Session Manager)
sudo ls -la /var/www/html/
sudo cat /var/log/user-data.log

# Check IAM policy
aws iam get-role-policy \
  --role-name capstone-ec2-role \
  --policy-name capstone-s3-policy
```

---

## Migration Guide (For Existing Deployments)

If you have an existing deployment with the old approach:

### Option 1: Clean Redeployment (Recommended)

```bash
# 1. Backup data
mysqldump -h $RDS_HOST -u admin -p country_schema > backup.sql

# 2. Destroy old infrastructure
terraform destroy

# 3. Upload to S3
./upload-to-s3.sh

# 4. Redeploy
terraform init
terraform apply

# 5. Restore data
mysql -h $NEW_RDS_HOST -u admin -p country_schema < backup.sql
```

### Option 2: In-Place Update (Advanced)

```bash
# 1. Upload to S3
./upload-to-s3.sh

# 2. Update Terraform files
# (already done in this update)

# 3. Apply changes
terraform apply

# 4. Replace launch template instances
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name capstone-asg
```

---

## Troubleshooting

### Common Issues After Migration

#### Issue: "S3 bucket not found"
**Cause:** terraform.tfvars not updated
**Solution:** Run `./upload-to-s3.sh` again

#### Issue: PHP files not on EC2
**Cause:** IAM policy not applied or NAT Gateway issue
**Solution:**
```bash
# Check IAM role
aws iam list-role-policies --role-name capstone-ec2-role

# Check NAT Gateway
aws ec2 describe-nat-gateways
```

#### Issue: Old user-data.sh cached
**Cause:** Launch template not updated
**Solution:**
```bash
terraform taint aws_launch_template.web
terraform apply
```

---

## Documentation Updated

| File | Status | Changes |
|------|--------|---------|
| `README.md` | ✅ Updated | Added S3 upload step |
| `QUICKSTART.md` | ✅ Updated | Renumbered steps, added S3 section |
| `COMPLETE_DOCUMENTATION.md` | ✅ Updated | Major rewrite of image setup section |
| `S3_DEPLOYMENT_GUIDE.md` | ⭐ NEW | Complete S3 deployment guide |
| `CHANGELOG.md` | ⭐ NEW | This file |

---

## Benefits Summary

### For Developers

✅ **Easier maintenance** - Edit files in `php-app/`, upload to S3
✅ **Faster iterations** - Update S3, restart instances
✅ **Better version control** - S3 versioning + Git
✅ **Cleaner code** - No heredocs, single source of truth

### For Operations

✅ **Production-ready** - Industry standard approach
✅ **Scalable** - S3 handles any load
✅ **Reliable** - S3 11 9's durability
✅ **Debuggable** - Clearer logs, easier troubleshooting

### For Business

✅ **Cost-effective** - Only $0.40/month for S3
✅ **Faster deployments** - Simpler process
✅ **Less risk** - Can rollback S3 versions
✅ **Professional** - Follows AWS best practices

---

## Next Steps

### Immediate

1. Test the new deployment process
2. Verify all files download correctly
3. Ensure application works as expected
4. Update any custom scripts or automation

### Future Enhancements

1. **CloudFront CDN** - Add CDN for faster global access
2. **CI/CD Pipeline** - Automate S3 uploads on git push
3. **Blue/Green Deployments** - Use S3 versioning for zero-downtime updates
4. **Multi-Region** - Replicate S3 bucket to other regions
5. **S3 Encryption** - Enable server-side encryption (optional)

---

## Rollback Plan

If issues occur, rollback is easy:

### Quick Rollback (Keep Infrastructure)

```bash
# Use previous S3 version
aws s3api list-object-versions \
  --bucket $(cat .s3-bucket-name) \
  --prefix php-app/

# Restore specific version
aws s3api copy-object \
  --copy-source bucket/key?versionId=xxx \
  --bucket bucket --key key

# Restart instances
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name capstone-asg
```

### Full Rollback (Revert Code)

```bash
# Revert git changes
git checkout HEAD~1

# Revert Terraform files
git checkout HEAD~1 main.tf variables.tf terraform.tfvars user-data.sh

# Redeploy
terraform apply
```

---

## Support

For issues or questions:

1. Check `S3_DEPLOYMENT_GUIDE.md` - Troubleshooting section
2. Review `user-data.log` on EC2 instances
3. Verify S3 bucket contents and permissions
4. Check IAM role policies

---

## Acknowledgments

This migration improves the project by:
- Following AWS best practices
- Reducing code duplication
- Improving maintainability
- Enabling production-ready deployments

The change from heredocs to S3 is a common pattern used by professional AWS deployments and represents industry best practices.

---

**Migration Status: ✅ COMPLETE**

All files updated, documented, and ready for deployment!
