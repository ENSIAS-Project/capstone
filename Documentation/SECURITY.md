# Security Best Practices

## 🔒 Overview

This document outlines the security measures implemented in this Capstone project and best practices for maintaining security.

---

## ✅ Security Measures Implemented

### 1. **Secrets Management**

#### Database Credentials
- **Random Password Generation**: Database passwords are generated using Terraform's `random_password` resource (main.tf:248-251)
- **AWS Secrets Manager**: Credentials are stored securely in AWS Secrets Manager (main.tf:254-273)
- **No Hardcoded Secrets**: Passwords are NEVER hardcoded in configuration files
- **EC2 IAM Access**: EC2 instances retrieve credentials via IAM roles, not environment variables

#### Configuration Files
- ✅ `terraform.tfvars` is ignored by git (.gitignore:13-14)
- ✅ `terraform.tfvars.example` is provided as a template
- ✅ `.s3-bucket-name` is ignored by git (.gitignore:40)
- ✅ SQL files with data are ignored (.gitignore:37)

### 2. **Network Security**

#### VPC Architecture
- Private subnets for EC2 instances (no direct internet access)
- Public subnets only for Application Load Balancer
- Dedicated database subnets in multiple AZs
- NAT Gateway for outbound traffic from private subnets

#### Security Groups (Principle of Least Privilege)
- **ALB Security Group** (main.tf:157-181): Only allows HTTP (port 80) from internet
- **Web Server Security Group** (main.tf:184-208): Only accepts traffic from ALB
- **RDS Security Group** (main.tf:211-235): Only accepts MySQL (port 3306) from web servers

### 3. **IAM Security**

#### EC2 Instance Role (main.tf:344-412)
- Minimal permissions principle
- Only allows:
  - Reading specific Secrets Manager secret
  - Reading from specific S3 bucket
- No admin or wildcard permissions

### 4. **Database Security**

- **Not Publicly Accessible**: `publicly_accessible = false` (main.tf:289)
- **Multi-AZ Capable**: Database subnets span multiple availability zones
- **Encrypted at Rest**: AWS RDS default encryption
- **Automated Backups**: RDS automatic backups enabled (default)

### 5. **Application Security**

- **No Secrets in Code**: PHP application retrieves DB credentials from AWS Secrets Manager
- **S3 Bucket Access**: Controlled via IAM roles, not access keys
- **Images Stored Separately**: Static assets can be served from S3/CloudFront

---

## 🚫 Files That Should NEVER Be Committed

The following files contain or may contain sensitive information:

1. **terraform.tfvars** - Contains your actual configuration values
2. **.s3-bucket-name** - Contains your S3 bucket name
3. **\*.tfstate** - May contain sensitive data in plain text
4. **\*.sql** - Database dumps may contain sensitive data
5. **\*.bak, \*.backup** - Backup files

**These are all listed in `.gitignore`** ✅

---

## 📋 Security Checklist for Deployment

Before deploying, verify:

- [ ] `terraform.tfvars` exists locally but is NOT in git
- [ ] Database username is changed from default "admin"
- [ ] AWS credentials are configured via `aws configure` (not hardcoded)
- [ ] S3 bucket is created and name is configured
- [ ] IAM permissions follow least privilege principle
- [ ] Security groups restrict traffic appropriately
- [ ] RDS is in private subnets only
- [ ] No AWS access keys are in code or config files

---

## 🔧 How to Use Secrets Safely

### For New Team Members

1. **Copy the example configuration:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Customize terraform.tfvars:**
   - Change database username from "admin"
   - Update region if needed
   - NEVER commit this file!

3. **Run the S3 upload script:**
   ```bash
   ./upload-to-s3.sh
   ```
   This will automatically update `terraform.tfvars` with your S3 bucket name.

4. **Deploy with Terraform:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Retrieving Secrets in Production

**EC2 Instances** automatically retrieve database credentials via:
- IAM Instance Profile (no credentials needed)
- AWS Secrets Manager API
- See `user-data.sh` for implementation

**Local Development:**
```bash
# Retrieve database password (requires AWS CLI configured)
aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --query SecretString \
  --output text | jq -r .password
```

---

## 🛡️ Additional Security Recommendations

### For Production Environments

1. **Enable HTTPS:**
   - Add ACM certificate to ALB
   - Redirect HTTP to HTTPS
   - Enable HTTPS in ALB listener

2. **Enable AWS GuardDuty:**
   - Threat detection for AWS account
   - Monitors for suspicious activity

3. **Enable AWS CloudTrail:**
   - Audit logging for all API calls
   - Track who accessed what and when

4. **Enable RDS Encryption:**
   - Already enabled by default in modern RDS
   - Verify: `storage_encrypted = true`

5. **Enable VPC Flow Logs:**
   - Monitor network traffic
   - Detect unusual patterns

6. **Implement WAF (Web Application Firewall):**
   - Protect against common web exploits
   - Rate limiting and IP blocking

7. **Regular Security Updates:**
   - Keep AMIs updated (Amazon Linux 2023 auto-updates)
   - Patch management for web servers

8. **Database Backups:**
   - Enable automated backups (already enabled)
   - Test restore procedures
   - Consider cross-region backup replication

9. **Secrets Rotation:**
   - Implement automatic password rotation in Secrets Manager
   - Rotate credentials every 90 days

10. **MFA for AWS Console:**
    - Require MFA for all IAM users
    - Especially for users with admin access

---

## 🔍 Security Audit Commands

### Check what's tracked in git:
```bash
git ls-files | grep -E "tfvars|tfstate|sql|key|secret"
```

### Verify Security Group Rules:
```bash
terraform show | grep -A 10 "security_group"
```

### Check IAM Permissions:
```bash
terraform show | grep -A 20 "iam_role_policy"
```

### Verify Database is Private:
```bash
terraform show | grep "publicly_accessible"
```

---

## 📚 References

- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform Security Best Practices](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

## 🚨 What to Do If Secrets Are Exposed

If you accidentally commit secrets to git:

1. **Immediately rotate the credentials:**
   ```bash
   # Generate new database password
   terraform taint random_password.db_password
   terraform apply
   ```

2. **Remove from git history:**
   ```bash
   # Use BFG Repo-Cleaner or git filter-branch
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch terraform.tfvars" \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **Force push (if already pushed to remote):**
   ```bash
   git push origin --force --all
   ```

4. **Notify your team**

5. **Check AWS CloudTrail for unauthorized access**

---

## 📞 Support

For security issues or questions:
- Review this document
- Check AWS documentation
- Consult with your security team
- Use AWS Support for critical issues

**Remember: Security is everyone's responsibility!** 🔒
