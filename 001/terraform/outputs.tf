# ========================================
# VPC Outputs
# ========================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ========================================
# Security Group Outputs
# ========================================

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "web_security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

# ========================================
# Application Load Balancer Outputs
# ========================================

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

# ========================================
# Auto Scaling Group Outputs
# ========================================

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.web.id
}

# ========================================
# Database Outputs
# ========================================

output "database_instance_id" {
  description = "ID of the database instance"
  value       = aws_instance.database.id
}

output "database_private_ip" {
  description = "Private IP address of the database instance"
  value       = aws_instance.database.private_ip
}

output "database_private_dns" {
  description = "Private DNS name of the database instance"
  value       = aws_instance.database.private_dns
}

# ========================================
# IAM Role Outputs
# ========================================

output "ec2_role_name" {
  description = "Name of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

# ========================================
# CloudWatch Outputs
# ========================================

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

# ========================================
# Load Testing Outputs
# ========================================

output "load_test_target_url" {
  description = "Target URL for load testing"
  value       = "http://${aws_lb.main.dns_name}"
}

output "load_test_commands" {
  description = "Commands to run load tests"
  value = {
    basic_test = "k6 run --vus 10 --duration 30s ../k6/load-test.js"
    stress_test = "k6 run --vus 100 --duration 2m ../k6/load-test.js"
  }
}

# ========================================
# Connection Information
# ========================================

output "session_manager_commands" {
  description = "AWS Session Manager commands for accessing instances"
  value = {
    web_instances = "aws ssm start-session --target <instance-id>"
    database_instance = "aws ssm start-session --target ${aws_instance.database.id}"
  }
}

# ========================================
# Monitoring URLs
# ========================================

output "monitoring_urls" {
  description = "URLs for monitoring and management"
  value = {
    cloudwatch_logs = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
    ec2_instances = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#Instances:"
    load_balancer = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#LoadBalancers:"
    auto_scaling = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#AutoScalingGroups:"
  }
}

# ========================================
# Cost Information
# ========================================

output "estimated_monthly_cost" {
  description = "Estimated monthly cost (USD)"
  value = {
    note = "This is an estimate based on current configuration"
    ec2_instances = "~$20-30/month for t3.micro instances"
    alb = "~$20/month for ALB"
    nat_gateway = "~$30/month for NAT Gateway"
    ebs_storage = "~$5-10/month for EBS volumes"
    total_estimate = "~$75-90/month"
  }
}
