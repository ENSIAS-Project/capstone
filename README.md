# AWS Capstone Project - Terraform Infrastructure

## 🚀 Quick Links

- **📖 [Complete Deployment Guide](Documentation/DEPLOYMENT_GUIDE.md)** - Start here!
- **🔒 [Security Documentation](Documentation/SECURITY.md)**
- **📝 [Change Log](Documentation/CHANGELOG.md)**

---

## Project Overview

This Terraform project deploys a **highly available web application** on AWS, replicating the AWS Academy Cloud Architecting Capstone Project. It includes:

✅ **Multi-AZ Infrastructure** - VPC with 2 availability zones
✅ **Auto Scaling** - 2-4 EC2 instances with automatic scaling
✅ **RDS MySQL** - Managed database for country data
✅ **Security** - Secrets Manager, Security Groups, IAM roles
✅ **Direct Instance Access** - Public IPs for development (ALB optional)

---

## Architecture

```
Internet → IGW → Public Subnets → EC2 Instances (2 AZs)
                      ↓
                 NAT Gateway
                      ↓
              RDS MySQL Database
                      ↓
              Secrets Manager & S3
```

**Current Configuration:**
- **Instances:** 2× t3.micro in public subnets
- **Database:** RDS MySQL 8.0 (db.t3.micro)
- **Access:** Direct via instance public IPs
- **Future:** ALB can be added when AWS account is fully activated

---

## Quick Start

### 1. Upload PHP Application to S3

```bash
./upload-to-s3.sh
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get Instance URLs

```bash
aws ec2 describe-instances \
  --filters 'Name=tag:Name,Values=capstone-web-server' \
            'Name=instance-state-name,Values=running' \
  --query 'Reservations[*].Instances[*].[PublicIpAddress]' \
  --output text
```

### 4. Import Database

```bash
RDS_HOST=$(terraform output -raw rds_address)
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

### 5. Test Application

Open in browser: `http://<instance-public-ip>/`

---

## 📖 Documentation

For complete deployment instructions, troubleshooting, and advanced configuration:

**👉 [Read the Complete Deployment Guide](Documentation/DEPLOYMENT_GUIDE.md)**

The guide includes:
- Detailed architecture diagrams
- Step-by-step deployment instructions
- Database import procedures
- Load balancer setup (for when ALB is available)
- Cost management strategies
- Comprehensive troubleshooting
- Complete cleanup procedures

---

## Key Features

### Current Setup (Without ALB)
- ✅ 2 EC2 instances across 2 availability zones
- ✅ Direct instance access via public IPs
- ✅ Auto Scaling Group (2-4 instances)
- ✅ RDS MySQL database with Secrets Manager
- ✅ Automated deployment with user-data scripts
- ✅ SSH access with key pair
- ✅ Cost-effective for development/testing

### Optional: Add Load Balancer
When your AWS account supports ALBs, you can:
- Add Application Load Balancer
- Move instances to private subnets
- Enable SSL/TLS with ACM
- Implement advanced health checks

See the [ALB Setup Section](Documentation/DEPLOYMENT_GUIDE.md#load-balancer-setup-optional) in the deployment guide.

---

## Project Structure

```
aws-capstone-terraform/
├── main.tf                    # Main infrastructure resources
├── provider.tf                # AWS provider configuration
├── variables.tf               # Variable definitions
├── terraform.tfvars           # Variable values (customize this)
├── outputs.tf                 # Output definitions
├── data.tf                    # Data sources (AMI, AZs)
├── user-data.sh               # EC2 initialization script
├── upload-to-s3.sh            # S3 upload script
├── countries.sql              # Database schema and data
├── capstone-key.pem           # SSH key (generated during setup)
├── php-app/                   # PHP application files
│   ├── index.php              # Homepage
│   ├── query.php              # Query interface
│   ├── get-parameters.php     # DB connection logic
│   ├── Logo.png               # Organization logo
│   ├── Shirley.jpeg           # Staff photo
│   └── ... (other PHP files)
└── Documentation/
    ├── DEPLOYMENT_GUIDE.md    # Complete deployment guide
    ├── SECURITY.md            # Security best practices
    └── CHANGELOG.md           # Version history
```

---

## Cost Estimate

**Monthly cost (us-east-1):** ~$60-65/month

| Resource | Monthly Cost |
|----------|--------------|
| NAT Gateway | ~$32 |
| RDS db.t3.micro | ~$12 |
| EC2 t3.micro (×2) | ~$17 |
| Other | ~$3 |

**With ALB:** ~$80-95/month (+$18-20 for ALB)

See [Cost Management](Documentation/DEPLOYMENT_GUIDE.md#cost-management) for optimization tips.

---

## Requirements

- **Terraform:** >= 1.0
- **AWS CLI:** >= 2.0 (configured with credentials)
- **MySQL Client:** For database import
- **AWS Account:** Academy Learner Lab or regular account

---

## Terraform Outputs

After deployment, you'll get:

```bash
terraform output
```

```
autoscaling_group_name = "capstone-asg"
instance_access_info = "Run: aws ec2 describe-instances..."
rds_endpoint = "capstone-mysql-db.xxx.us-east-1.rds.amazonaws.com:3306"
secrets_manager_secret_arn = "arn:aws:secretsmanager:..."
vpc_id = "vpc-xxx"
```

---

## Common Commands

### View Resources
```bash
terraform show               # Show current state
terraform output             # Show all outputs
terraform state list         # List all resources
```

### Manage Infrastructure
```bash
terraform plan               # Preview changes
terraform apply              # Apply changes
terraform destroy            # Delete everything
```

### Check Deployment Status
```bash
# Check instances
aws ec2 describe-instances --filters 'Name=tag:Name,Values=capstone-web-server'

# Check Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names capstone-asg

# Check RDS
aws rds describe-db-instances --db-instance-identifier capstone-mysql-db
```

---

## Troubleshooting

**Instance not accessible?**
- Verify security group has port 80 open
- Check Apache is running: `sudo systemctl status httpd`
- View logs: `sudo cat /var/log/user-data.log`

**Database connection failed?**
- Verify RDS is available
- Check security group allows port 3306
- Test connection: `mysql -h <endpoint> -u admin -p`

**SSH connection refused?**
- Verify security group has port 22 open
- Check key permissions: `chmod 400 capstone-key.pem`
- Use EC2 Instance Connect as alternative

For detailed troubleshooting: [Troubleshooting Guide](Documentation/DEPLOYMENT_GUIDE.md#troubleshooting)

---

## Cleanup

When you're done:

```bash
# Destroy all infrastructure
terraform destroy

# Delete S3 bucket
BUCKET_NAME=$(cat .s3-bucket-name)
aws s3 rb s3://$BUCKET_NAME --force

# Delete SSH key
aws ec2 delete-key-pair --key-name capstone-key
rm capstone-key.pem
```

---

## Security

This project implements AWS security best practices:

- ✅ **No Hardcoded Credentials** - Uses Secrets Manager
- ✅ **Least Privilege IAM** - Minimal permissions for EC2 roles
- ✅ **Security Groups** - Proper network isolation
- ✅ **Multi-AZ** - High availability across zones
- ✅ **Private Subnets Ready** - Easy migration when adding ALB

See [SECURITY.md](Documentation/SECURITY.md) for details.

---

## Success Checklist

- [ ] PHP files uploaded to S3
- [ ] Terraform apply completed successfully
- [ ] 2 instances running in different AZs
- [ ] Both instances accessible via HTTP
- [ ] Database imported (227 countries)
- [ ] Query functionality works
- [ ] SSH access configured

---

## Additional Resources

- 📖 [Complete Deployment Guide](Documentation/DEPLOYMENT_GUIDE.md)
- 🔒 [Security Best Practices](Documentation/SECURITY.md)
- 📚 [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- 🏗️ [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

## Course Information

**AWS Academy Cloud Architecting - Capstone Project**

This infrastructure replicates the AWS Academy Capstone lab using Infrastructure as Code principles, making it repeatable, version-controlled, and production-ready.

**Version:** 2.0 (Updated October 2025)

---

## License

Educational use - AWS Academy Capstone Project Implementation

---

**Need Help?** Check the [Complete Deployment Guide](Documentation/DEPLOYMENT_GUIDE.md) for detailed instructions and troubleshooting.
