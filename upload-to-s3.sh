#!/bin/bash
# Script to upload PHP application files and images to S3
# This makes deployment cleaner and easier to maintain

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Capstone - S3 Upload Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI first"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run 'aws configure' first"
    exit 1
fi

# Create unique bucket name with timestamp
TIMESTAMP=$(date +%s)
BUCKET_NAME="capstone-php-app-${TIMESTAMP}"
REGION="us-east-1"

echo -e "${YELLOW}Bucket name:${NC} $BUCKET_NAME"
echo -e "${YELLOW}Region:${NC} $REGION"
echo ""

# Create S3 bucket
echo -e "${GREEN}Step 1: Creating S3 bucket...${NC}"
if aws s3 mb s3://$BUCKET_NAME --region $REGION; then
    echo -e "${GREEN}✓ Bucket created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create bucket${NC}"
    exit 1
fi
echo ""

# Enable versioning on the bucket (optional but recommended)
echo -e "${GREEN}Step 2: Enabling versioning...${NC}"
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled \
    --region $REGION
echo -e "${GREEN}✓ Versioning enabled${NC}"
echo ""

# Upload PHP application files
echo -e "${GREEN}Step 3: Uploading PHP application files...${NC}"
if [ -d "php-app" ]; then
    aws s3 sync php-app/ s3://$BUCKET_NAME/php-app/ \
        --exclude "*.md" \
        --exclude ".DS_Store" \
        --region $REGION
    echo -e "${GREEN}✓ PHP files uploaded${NC}"
else
    echo -e "${RED}✗ php-app directory not found${NC}"
    exit 1
fi
echo ""

# List uploaded files
echo -e "${GREEN}Step 4: Verifying uploaded files...${NC}"
echo -e "${YELLOW}Files in S3:${NC}"
aws s3 ls s3://$BUCKET_NAME/php-app/ --recursive
echo ""

# Make files readable by EC2 instances (set bucket policy)
echo -e "${GREEN}Step 5: Setting bucket policy...${NC}"
cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowEC2ToReadObjects",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
            "Condition": {
                "StringEquals": {
                    "aws:PrincipalOrgID": "\${aws:PrincipalOrgID}"
                }
            }
        }
    ]
}
EOF

# Note: The above policy allows access from your AWS organization
# For broader access (like from EC2 with IAM role), we'll use IAM instead
echo -e "${YELLOW}Note: EC2 instances will use IAM role to access S3${NC}"
echo ""

# Count uploaded files
FILE_COUNT=$(aws s3 ls s3://$BUCKET_NAME/php-app/ --recursive | wc -l)
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Upload Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Bucket Name: ${GREEN}$BUCKET_NAME${NC}"
echo -e "  Region: ${GREEN}$REGION${NC}"
echo -e "  Files Uploaded: ${GREEN}$FILE_COUNT${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Update terraform.tfvars with the bucket name:"
echo -e "     ${GREEN}s3_php_app_bucket = \"$BUCKET_NAME\"${NC}"
echo ""
echo -e "  2. Or export as environment variable:"
echo -e "     ${GREEN}export TF_VAR_s3_php_app_bucket=\"$BUCKET_NAME\"${NC}"
echo ""
echo -e "  3. Run terraform apply:"
echo -e "     ${GREEN}terraform apply${NC}"
echo ""

# Save bucket name to a file for easy reference
echo $BUCKET_NAME > .s3-bucket-name
echo -e "${GREEN}✓ Bucket name saved to .s3-bucket-name${NC}"
echo ""

echo -e "${YELLOW}Cost Note:${NC}"
echo "  S3 storage costs approximately \$0.023/GB/month"
echo "  Your PHP files are ~few KB, so cost is negligible (~\$0.01/month)"
echo ""

# Ask if user wants to update terraform.tfvars automatically
echo -e "${YELLOW}Would you like to update terraform.tfvars automatically? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    if [ -f "terraform.tfvars" ]; then
        # Check if s3_php_app_bucket already exists
        if grep -q "s3_php_app_bucket" terraform.tfvars; then
            # Update existing value
            sed -i.bak "s|s3_php_app_bucket.*|s3_php_app_bucket = \"$BUCKET_NAME\"|" terraform.tfvars
            echo -e "${GREEN}✓ Updated existing s3_php_app_bucket in terraform.tfvars${NC}"
        else
            # Add new value
            echo "" >> terraform.tfvars
            echo "# S3 bucket for PHP application files" >> terraform.tfvars
            echo "s3_php_app_bucket = \"$BUCKET_NAME\"" >> terraform.tfvars
            echo -e "${GREEN}✓ Added s3_php_app_bucket to terraform.tfvars${NC}"
        fi
    else
        echo -e "${YELLOW}terraform.tfvars not found, skipping...${NC}"
    fi
fi

echo ""
echo -e "${GREEN}All done! You're ready to deploy.${NC}"
