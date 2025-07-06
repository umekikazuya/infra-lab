#!/bin/bash

# ========================================
# Load Testing Script
# ========================================

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if k6 is installed
if ! command -v k6 >/dev/null 2>&1; then
    print_warning "k6 is not installed. Installing k6..."
    
    # Install k6 on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew >/dev/null 2>&1; then
            brew install k6
        else
            print_warning "Homebrew not found. Please install k6 manually:"
            echo "https://k6.io/docs/getting-started/installation/"
            exit 1
        fi
    else
        print_warning "Please install k6 manually:"
        echo "https://k6.io/docs/getting-started/installation/"
        exit 1
    fi
fi

# Get ALB DNS name from Terraform output
cd "$(dirname "$0")/terraform"
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")

if [ -z "$ALB_DNS" ]; then
    print_warning "Could not get ALB DNS name from Terraform output."
    read -p "Please enter the ALB DNS name: " ALB_DNS
fi

if [ -z "$ALB_DNS" ]; then
    echo "ALB DNS name is required for load testing."
    exit 1
fi

cd ../k6

BASE_URL="http://$ALB_DNS"

print_status "Starting load tests against: $BASE_URL"

# Test 1: Basic connectivity test
print_status "Test 1: Basic connectivity test"
k6 run --vus 1 --duration 10s --env BASE_URL=$BASE_URL load-test.js

# Test 2: Light load test
print_status "Test 2: Light load test (10 users, 1 minute)"
k6 run --vus 10 --duration 1m --env BASE_URL=$BASE_URL load-test.js

# Test 3: Medium load test
print_status "Test 3: Medium load test (50 users, 2 minutes)"
k6 run --vus 50 --duration 2m --env BASE_URL=$BASE_URL load-test.js

# Test 4: Stress test
print_status "Test 4: Stress test (100 users, 3 minutes)"
k6 run --vus 100 --duration 3m --env BASE_URL=$BASE_URL load-test.js

print_success "Load testing completed!"
print_status "Check the results above and CloudWatch metrics for performance analysis."
