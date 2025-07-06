# ========================================
# Project Configuration
# ========================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "lamp-infra"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# ========================================
# Networking Configuration
# ========================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ========================================
# EC2 Configuration
# ========================================

variable "web_instance_type" {
  description = "Instance type for web servers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "Instance type for database server"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = ""
}

# ========================================
# Auto Scaling Configuration
# ========================================

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# ========================================
# Database Configuration
# ========================================

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  default     = "MySecurePassword123!"
  sensitive   = true
}

variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "webapp"
}

variable "mysql_user" {
  description = "MySQL application user"
  type        = string
  default     = "webuser"
}

variable "mysql_password" {
  description = "MySQL application user password"
  type        = string
  default     = "WebUserPassword123!"
  sensitive   = true
}

# ========================================
# Monitoring Configuration
# ========================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for EC2 instances"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# ========================================
# SSL/TLS Configuration
# ========================================

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = ""
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for ALB"
  type        = bool
  default     = false
}

# ========================================
# Tags
# ========================================

variable "default_tags" {
  description = "Default tags to be applied to all resources"
  type        = map(string)
  default = {
    Project     = "LAMP Infrastructure"
    Environment = "dev"
    Owner       = "DevOps Team"
    CreatedBy   = "Terraform"
  }
}

# ========================================
# Security Configuration
# ========================================

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the application"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail"
  type        = bool
  default     = true
}

# ========================================
# Cost Optimization
# ========================================

variable "enable_spot_instances" {
  description = "Use Spot Instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_price" {
  description = "Maximum price for Spot Instances"
  type        = string
  default     = "0.05"
}

variable "enable_auto_shutdown" {
  description = "Enable automatic shutdown for development environment"
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Time for automatic shutdown (24h format)"
  type        = string
  default     = "19:00"
}

variable "auto_startup_time" {
  description = "Time for automatic startup (24h format)"
  type        = string
  default     = "09:00"
}
