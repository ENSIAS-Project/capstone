# AWS Academy Capstone Project - Terraform Infrastructure

This Terraform configuration deploys a highly available, secure web application infrastructure on AWS based on the AWS Academy Cloud Architecting Capstone Project requirements.

## Architecture Overview

The infrastructure includes:
- **VPC** with public, private, and database subnets across 2 Availability Zones
- **Application Load Balancer** in public subnets for distributing traffic
- **Auto Scaling Group** with EC2 instances in private subnets
- **RDS MySQL Database** in private database subnets
- **NAT Gateway** for private subnet internet access
- **AWS Secrets Manager** for secure database credential storage
- **Security Groups** with proper least-privilege access controls

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (version >= 1.0)
3. **AWS CLI** configured with credentials:
   ```bash
   aws configure
   ```

## Project Structure

```
aws-capstone-terraform/
├── main.tf              # Main infrastructure resources
├── provider.tf          # Provider configuration
├── variables.tf         # Variable definitions
├── terraform.tfvars     # Variable values (customize this)
├── outputs.tf           # Output definitions
├── data.tf              # Data sources
├── user-data.sh         # EC2 instance initialization script
├── upload-to-s3.sh      # Script to upload PHP files to S3
├── php-app/             # PHP application files and images
│   ├── index.php
│   ├── query.php
│   ├── Logo.png
│   ├── Shirley.jpeg
│   └── ... (other PHP files)
├── .gitignore           # Git ignore rules
└── README.md            # This file
```

## Deployment Steps

### 1. Clone or Create Project Directory

```bash
mkdir aws-capstone-terraform
cd aws-capstone-terraform
# Copy all the Terraform files here
```

### 2. Upload PHP Application Files to S3

**IMPORTANT:** Before deploying infrastructure, upload the PHP application files to S3:

```bash
# Make the script executable
chmod +x upload-to-s3.sh

# Run the upload script
./upload-to-s3.sh
```

This script will:
- Create a new S3 bucket with a unique name
- Upload all PHP files and images from the `php-app/` directory
- Enable versioning on the bucket
- Automatically update `terraform.tfvars` with the bucket name

**Note:** The bucket name will be saved to `.s3-bucket-name` for reference.

### 3. Customize Variables (Optional)

Edit `terraform.tfvars` to customize:
- AWS region
- Instance types
- Auto Scaling group sizes
- Database configurations

### 4. Initialize Terraform

```bash
terraform init
```

This downloads the required provider plugins.

### 5. Review the Execution Plan

```bash
terraform plan
```

Review the resources that will be created. Look for:
- VPC and networking components
- Security groups
- RDS instance
- Load balancer
- Auto Scaling group
- IAM roles with S3 and Secrets Manager permissions

### 6. Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Deployment takes approximately 10-15 minutes (RDS creation is the longest step).

**What happens during deployment:**
- EC2 instances will automatically download the PHP application files from S3
- AWS SDK for PHP will be installed via Composer
- Apache web server will be configured and started
- Health checks will verify the application is running

### 7. Get Outputs

After successful deployment:

```bash
terraform output
```

You'll see:
- **alb_url**: Use this URL to access your web application
- **rds_endpoint**: Database endpoint
- **secrets_manager_secret_arn**: ARN of the database credentials

### 8. Import Database Data

You need to import the countries data into your RDS database:

```bash
# Get RDS endpoint
RDS_HOST=$(terraform output -raw rds_address)

# Get database password
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id capstone-db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r '.password')

# Import the data
mysql -h $RDS_HOST -u admin -p$DB_PASS country_schema < countries.sql
```

### 9. Test the Application

Open the ALB URL in your browser:
```
http://<alb-dns-name>
```

You should see the Social Research Organization homepage where you can query country data.

## Cost Considerations

This infrastructure will incur AWS charges. Main cost factors:
- **NAT Gateway**: ~$0.045/hour + data transfer
- **RDS db.t3.micro**: ~$0.017/hour
- **EC2 t2.micro instances**: ~$0.0116/hour each (2 by default)
- **Application Load Balancer**: ~$0.0225/hour + LCU charges

**Estimated monthly cost**: $50-80 USD (varies by usage and region)

### Cost Optimization Tips:

1. **Stop resources when not in use**:
   ```bash
   # Stop RDS instance (will auto-restart after 7 days)
   aws rds stop-db-instance --db-instance-identifier capstone-mysql-db
   
   # Set Auto Scaling to 0 instances
   aws autoscaling set-desired-capacity --auto-scaling-group-name capstone-asg --desired-capacity 0
   ```

2. **Delete NAT Gateway when testing** (will break private subnet internet access)

3. **Use the destroy command when done**:
   ```bash
   terraform destroy
   ```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` to confirm. This will delete all infrastructure created by Terraform.

**WARNING**: This is irreversible and will delete all data!

## Security Features

- ✅ Web servers in private subnets (no direct internet access)
- ✅ Database in isolated subnets (accessible only from web servers)
- ✅ Secrets Manager for database credentials (no hardcoded passwords)
- ✅ Security groups with least-privilege access
- ✅ ALB for public-facing access (shields backend servers)
- ✅ IAM roles for EC2 with minimal required permissions

## Troubleshooting

### Issue: Application not loading
- Check ALB target group health in AWS Console
- Verify EC2 instances are running and registered with target group
- Check security group rules

### Issue: Database connection failed
- Verify RDS instance is available
- Check security group allows traffic from web server security group
- Verify Secrets Manager secret exists and is accessible

### Issue: Terraform apply fails
- Check AWS credentials are configured correctly
- Verify you have necessary IAM permissions
- Check for service quotas/limits in your AWS account

## Modifications

### Change Instance Count
Edit `terraform.tfvars`:
```hcl
asg_min_size         = 3
asg_max_size         = 6
asg_desired_capacity = 3
```

Then run:
```bash
terraform apply
```

### Change Region
Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
```

Then run:
```bash
terraform apply
```

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

## License

This project is for educational purposes as part of AWS Academy Cloud Architecting course.
