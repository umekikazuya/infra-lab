#!/bin/bash

# ========================================
# LAMP Infrastructure Deployment Script
# ========================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists terraform; then
    print_error "Terraform is not installed. Please install Terraform first."
    exit 1
fi

if ! command_exists aws; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_error "AWS credentials are not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "Prerequisites check passed!"

# Change to terraform directory
cd "$(dirname "$0")/terraform"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_warning "Please edit terraform.tfvars with your specific values before proceeding."
    exit 1
fi

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
terraform validate

# Plan deployment
print_status "Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo
print_warning "Review the plan above. Do you want to proceed with the deployment?"
read -p "Enter 'yes' to continue: " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_error "Deployment cancelled."
    exit 1
fi

# Apply deployment
print_status "Applying deployment..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

print_success "Deployment completed!"

# Output important information
echo
print_status "Getting deployment outputs..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
DB_PRIVATE_IP=$(terraform output -raw database_private_ip 2>/dev/null || echo "Not available")

echo
print_success "=== Deployment Information ==="
echo "ALB DNS Name: $ALB_DNS"
echo "Database Private IP: $DB_PRIVATE_IP"
echo "Web Application URL: http://$ALB_DNS"
echo

print_status "=== Next Steps ==="
echo "1. Wait 5-10 minutes for instances to fully initialize"
echo "2. Access the web application: http://$ALB_DNS"
echo "3. Check the health endpoint: http://$ALB_DNS/health.php"
echo "4. Run load tests: cd ../k6 && k6 run --env BASE_URL=http://$ALB_DNS load-test.js"
echo "5. Monitor CloudWatch logs and metrics"
echo

print_success "Deployment script completed!"
