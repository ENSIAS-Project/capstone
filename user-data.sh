#!/bin/bash
# User Data Script for Web Server Configuration
# This script downloads and deploys the Example Social Research Organization PHP application from S3

# Don't exit on error - we want to continue even if S3 download fails
# set -e

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

# Install required packages with PHP 8.x
echo "Step 2: Installing required packages with PHP 8..."

# For Amazon Linux 2, enable PHP 8.1 from amazon-linux-extras
echo "Enabling PHP 8.1 from amazon-linux-extras..."
amazon-linux-extras enable php8.1

# Clean yum cache to ensure we get latest packages
yum clean metadata

# Install Apache and PHP 8.1 with required extensions
yum install -y httpd php php-mysqlnd php-xml php-mbstring php-zip php-json php-curl php-cli php-process php-gd

# Install other required packages
yum install -y mysql git jq curl unzip wget

# Verify PHP version
echo "Installed PHP version:"
php -v

# Start and enable Apache
echo "Step 3: Starting Apache..."
systemctl start httpd
systemctl enable httpd

# Verify Apache is running
if systemctl is-active --quiet httpd; then
    echo "✓ Apache is running"
else
    echo "✗ Apache failed to start"
    systemctl status httpd --no-pager
    exit 1
fi

# Create health check file IMMEDIATELY after Apache starts (for ALB health checks)
echo "Step 4: Creating health check file..."
mkdir -p /var/www/html
echo "OK" > /var/www/html/health.txt
chown apache:apache /var/www/html/health.txt
chmod 644 /var/www/html/health.txt
echo "✓ Health check file created at /var/www/html/health.txt"

# Create a simple test page as fallback
echo "Step 4b: Creating test index page..."
cat > /var/www/html/test.html << 'EOFTEST'
<!DOCTYPE html>
<html>
<head><title>Server Test</title></head>
<body>
<h1>Server is Running</h1>
<p>This page confirms Apache is working correctly.</p>
</body>
</html>
EOFTEST
chown apache:apache /var/www/html/test.html

# Install AWS CLI v2 if not present
if ! command -v aws &> /dev/null; then
    echo "Step 5: Installing AWS CLI v2..."
    cd /tmp
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "Step 5: AWS CLI already installed"
fi

# Create web application directory
echo "Step 6: Setting up web directory..."
cd /var/www/html
# Remove default index.html but keep health.txt
rm -f index.html
# Ensure health.txt still exists
if [ ! -f "health.txt" ]; then
    echo "WARNING: health.txt was removed, recreating..."
    echo "OK" > health.txt
    chown apache:apache health.txt
    chmod 644 health.txt
fi

# Install Composer for AWS SDK
echo "Step 7: Installing Composer..."
cd /var/www/html
export COMPOSER_HOME=/var/www/html
export COMPOSER_ALLOW_SUPERUSER=1

# Download and install Composer with better error handling
echo "Downloading Composer installer..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

if [ -f "composer-setup.php" ]; then
    echo "Running Composer installer..."
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php

    if [ -f "/usr/local/bin/composer" ]; then
        chmod +x /usr/local/bin/composer
        echo "✓ Composer installed successfully"
        /usr/local/bin/composer --version
    else
        echo "✗ Composer installation failed"
    fi
else
    echo "✗ Failed to download Composer installer"
fi

# Install AWS SDK for PHP
echo "Step 8: Installing AWS SDK for PHP..."
cd /var/www/html

# Create composer.json
cat > composer.json << 'EOFCOMPOSER'
{
    "require": {
        "aws/aws-sdk-php": "^3.0"
    }
}
EOFCOMPOSER

echo "Installing AWS SDK via Composer..."
if [ -f "/usr/local/bin/composer" ]; then
    # Run composer install with proper error handling
    /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tee /tmp/composer-install.log

    # Check if vendor directory was created
    if [ -d "/var/www/html/vendor" ] && [ -d "/var/www/html/vendor/aws" ]; then
        echo "✓ AWS SDK installed successfully"
        ls -la /var/www/html/vendor/aws/ | head -5
    else
        echo "✗ AWS SDK installation failed"
        echo "Composer install log:"
        cat /tmp/composer-install.log

        # Try alternative installation method - direct download
        echo "Attempting alternative installation..."
        mkdir -p /var/www/html/vendor/aws
        cd /var/www/html/vendor
        wget https://github.com/aws/aws-sdk-php/releases/download/3.316.2/aws.zip
        unzip -q aws.zip
        rm aws.zip
    fi
else
    echo "✗ Composer not found, using alternative AWS SDK installation"
    mkdir -p /var/www/html/vendor/aws
    cd /var/www/html/vendor
    wget https://github.com/aws/aws-sdk-php/releases/download/3.316.2/aws.zip
    unzip -q aws.zip
    rm aws.zip
fi

# Create aws-autoloader.php (referenced by get-parameters.php)
cat > aws-autoloader.php << 'EOFAUTOLOAD'
<?php
require '/var/www/html/vendor/autoload.php';
?>
EOFAUTOLOAD

# Download PHP application files from S3
echo "Step 9: Downloading PHP application files from S3..."
cd /var/www/html
if [ -n "$S3_BUCKET" ]; then
    echo "Downloading from s3://$S3_BUCKET/php-app/..."

    # Download all PHP files (exclude health.txt to preserve it)
    aws s3 sync s3://$S3_BUCKET/php-app/ /var/www/html/ \
        --region $AWS_REGION \
        --exclude "*.md" \
        --exclude ".DS_Store" \
        --exclude "health.txt"

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
echo "Step 10: Verifying PHP files..."
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
echo "Step 11: Setting up CSS directory..."
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

# Import database
echo "Step 11.5: Importing database from S3..."
if [ -n "$S3_BUCKET" ]; then
    # Download countries.sql from S3
    aws s3 cp s3://$S3_BUCKET/countries.sql /tmp/countries.sql --region $AWS_REGION

    if [ $? -eq 0 ]; then
        echo "✓ countries.sql downloaded successfully"

        # Get database credentials from Secrets Manager
        echo "Retrieving database credentials..."
        SECRET=$(aws secretsmanager get-secret-value \
            --secret-id capstone-db-credentials \
            --region $AWS_REGION \
            --query SecretString \
            --output text)

        if [ $? -eq 0 ]; then
            DB_HOST=$(echo $SECRET | jq -r '.host')
            DB_USER=$(echo $SECRET | jq -r '.username')
            DB_PASS=$(echo $SECRET | jq -r '.password')
            DB_NAME=$(echo $SECRET | jq -r '.dbname')

            echo "Database Host: $DB_HOST"
            echo "Database Name: $DB_NAME"

            # Wait for RDS to be available (max 5 minutes)
            echo "Waiting for database to be available..."
            RETRY_COUNT=0
            MAX_RETRIES=30
            while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
                if mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -e "SELECT 1" > /dev/null 2>&1; then
                    echo "✓ Database connection successful"
                    break
                else
                    echo "Waiting for database... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
                    sleep 10
                    RETRY_COUNT=$((RETRY_COUNT+1))
                fi
            done

            if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
                echo "✗ Database connection timeout"
            else
                # Import the database
                echo "Importing countries data..."
                mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME < /tmp/countries.sql

                if [ $? -eq 0 ]; then
                    echo "✓ Database imported successfully"

                    # Verify import
                    COUNTRY_COUNT=$(mysql -h $DB_HOST -u $DB_USER -p$DB_PASS -N -e "USE $DB_NAME; SELECT COUNT(*) FROM countrydata_final;")
                    echo "✓ Imported $COUNTRY_COUNT countries"
                else
                    echo "✗ Database import failed"
                fi
            fi
        else
            echo "✗ Failed to retrieve database credentials from Secrets Manager"
        fi

        # Clean up
        rm -f /tmp/countries.sql
    else
        echo "✗ Failed to download countries.sql from S3"
    fi
else
    echo "✗ S3_BUCKET not set, skipping database import"
fi

# Set proper permissions
echo "Step 12: Setting permissions..."
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache to ensure all changes take effect
echo "Step 13: Restarting Apache..."
systemctl restart httpd

# Ensure health check file still exists and is accessible
echo "Step 14: Verifying health check file..."
if [ -f "/var/www/html/health.txt" ]; then
    echo "✓ Health check file exists"
    ls -lh /var/www/html/health.txt
else
    echo "✗ Health check file missing - recreating..."
    echo "OK" > /var/www/html/health.txt
    chown apache:apache /var/www/html/health.txt
    chmod 644 /var/www/html/health.txt
fi

# Test health check endpoint locally
echo "Step 14b: Testing health check endpoint..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost/health.txt)
if [ "$HEALTH_CHECK" == "200" ]; then
    echo "✓ Health check endpoint responding with HTTP 200"
else
    echo "✗ Health check endpoint returned HTTP $HEALTH_CHECK"
    echo "Debugging information:"
    curl -v http://localhost/health.txt
fi

# Test Apache configuration
echo "Step 15: Testing Apache configuration..."
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
