#!/bin/bash
# User Data Script for Web Server Configuration
# This script downloads and deploys the Example Social Research Organization PHP application from S3

set -e  # Exit on error

# Log output to file for troubleshooting
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=================================="
echo "Starting Web Server Configuration"
echo "=================================="
date

# Variables (will be replaced by Terraform)
S3_BUCKET="${s3_bucket_name}"
AWS_REGION="${aws_region}"

echo "S3 Bucket: $S3_BUCKET"
echo "Region: $AWS_REGION"

# Update system
echo "Step 1: Updating system..."
yum update -y

# Install required packages
echo "Step 2: Installing required packages..."
yum install -y httpd php php-mysqli mysql git jq

# Start and enable Apache
echo "Step 3: Starting Apache..."
systemctl start httpd
systemctl enable httpd

# Install AWS CLI v2 if not present
if ! command -v aws &> /dev/null; then
    echo "Step 4: Installing AWS CLI v2..."
    cd /tmp
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "Step 4: AWS CLI already installed"
fi

# Install Composer for AWS SDK
echo "Step 5: Installing Composer..."
cd /tmp
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Create web application directory
echo "Step 6: Setting up web directory..."
cd /var/www/html
rm -f index.html

# Install AWS SDK for PHP
echo "Step 7: Installing AWS SDK for PHP..."
cat > composer.json << 'EOFCOMPOSER'
{
    "require": {
        "aws/aws-sdk-php": "^3.0"
    }
}
EOFCOMPOSER

composer install --no-dev --quiet

# Create aws-autoloader.php (referenced by get-parameters.php)
cat > aws-autoloader.php << 'EOFAUTOLOAD'
<?php
require '/var/www/html/vendor/autoload.php';
?>
EOFAUTOLOAD

# Download PHP application files from S3
echo "Step 8: Downloading PHP application files from S3..."
if [ -n "$S3_BUCKET" ]; then
    echo "Downloading from s3://$S3_BUCKET/php-app/..."

    # Download all PHP files
    aws s3 sync s3://$S3_BUCKET/php-app/ /var/www/html/ \
        --region $AWS_REGION \
        --exclude "*.md" \
        --exclude ".DS_Store"

    if [ $? -eq 0 ]; then
        echo "✓ PHP application files downloaded successfully"
        ls -lah /var/www/html/
    else
        echo "✗ Failed to download PHP files from S3"
        echo "Creating fallback index.html..."
        cat > /var/www/html/index.html << 'EOFHTML'
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Error</title>
</head>
<body>
    <h1>Deployment Error</h1>
    <p>Failed to download PHP application files from S3.</p>
    <p>Please check:</p>
    <ul>
        <li>S3 bucket exists and is accessible</li>
        <li>IAM role has S3 read permissions</li>
        <li>Files were uploaded to S3 using upload-to-s3.sh</li>
    </ul>
</body>
</html>
EOFHTML
    fi
else
    echo "✗ S3_BUCKET variable not set"
    echo "Creating fallback index.html..."
    cat > /var/www/html/index.html << 'EOFHTML'
<!DOCTYPE html>
<html>
<head>
    <title>Configuration Error</title>
</head>
<body>
    <h1>Configuration Error</h1>
    <p>S3 bucket name not provided to user-data script.</p>
    <p>Please ensure terraform.tfvars has s3_php_app_bucket set.</p>
</body>
</html>
EOFHTML
fi

# Verify critical files exist
echo "Step 9: Verifying PHP files..."
REQUIRED_FILES=("index.php" "query.php" "query2.php" "get-parameters.php" "Logo.png" "Shirley.jpeg")
MISSING_FILES=()

for file in "$${REQUIRED_FILES[@]}"; do
    if [ ! -f "/var/www/html/$file" ]; then
        echo "✗ Missing: $file"
        MISSING_FILES+=("$file")
    else
        echo "✓ Found: $file"
    fi
done

if [ $${#MISSING_FILES[@]} -gt 0 ]; then
    echo "WARNING: $${#MISSING_FILES[@]} files are missing"
fi

# Create CSS directory if it doesn't exist
echo "Step 10: Setting up CSS directory..."
mkdir -p /var/www/html/css

# Check if styles.css exists, if not create a basic one
if [ ! -f "/var/www/html/css/styles.css" ]; then
    echo "Creating basic styles.css..."
    cat > /var/www/html/css/styles.css << 'EOFCSS'
/* Basic styles for Example Social Research Organization */
body.bodyStyle {
    font-family: Arial, sans-serif;
    margin: 0;
    padding: 20px;
    background-color: #f5f5f5;
}

.mainHeader {
    background-color: #2c3e50;
    color: white;
    padding: 20px;
    text-align: center;
}

.center {
    text-align: center;
}

.topnav {
    background-color: #34495e;
    overflow: hidden;
    text-align: center;
    padding: 10px;
}

.topnav a {
    color: white;
    text-decoration: none;
    padding: 14px 20px;
    display: inline-block;
}

.topnav a:hover {
    background-color: #1abc9c;
}

.cursiveText {
    font-style: italic;
    font-size: 1.1em;
    color: #555;
}

table {
    margin: 0 auto;
    border-collapse: collapse;
}

table td {
    padding: 10px;
}

hr {
    border: 1px solid #ddd;
}

h1, h2, h3 {
    color: #2c3e50;
}
EOFCSS
fi

# Set proper permissions
echo "Step 11: Setting permissions..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache to ensure all changes take effect
echo "Step 12: Restarting Apache..."
systemctl restart httpd

# Create health check file for ALB
echo "Step 13: Creating health check file..."
echo "OK" > /var/www/html/health.txt

# Test Apache configuration
echo "Step 14: Testing Apache configuration..."
httpd -t

# Display final status
echo "=================================="
echo "Configuration Complete!"
echo "=================================="
date

# Show what's running
echo ""
echo "Service Status:"
systemctl status httpd --no-pager | head -5

echo ""
echo "Web Directory Contents:"
ls -lh /var/www/html/

echo ""
echo "PHP Files:"
find /var/www/html -name "*.php" -type f

echo ""
echo "Image Files:"
find /var/www/html \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -type f

echo ""
echo "Log file location: /var/log/user-data.log"
echo "You can view this log anytime with: sudo cat /var/log/user-data.log"
echo ""
echo "✓ Web server is ready!"
