#!/bin/bash

# ========================================
# Database Server Setup Script
# Amazon Linux 2 - MySQL 8.0 + CloudWatch Agent
# ========================================

# Update system
yum update -y

# Install required packages
yum install -y \
    mysql-server \
    mysql \
    amazon-cloudwatch-agent \
    awslogs \
    htop \
    git \
    unzip

# Configure MySQL
systemctl start mysqld
systemctl enable mysqld

# Wait for MySQL to start
sleep 10

# Get temporary root password
TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')

# Set MySQL root password and configure security
mysql --connect-expired-password -u root -p"$TEMP_PASSWORD" << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_root_password}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Create application database and user
mysql -u root -p"${mysql_root_password}" << EOF
CREATE DATABASE IF NOT EXISTS ${mysql_database};
CREATE USER IF NOT EXISTS '${mysql_user}'@'%' IDENTIFIED BY '${mysql_password}';
GRANT ALL PRIVILEGES ON ${mysql_database}.* TO '${mysql_user}'@'%';
FLUSH PRIVILEGES;

-- Create sample tables
USE ${mysql_database};

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS access_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45),
    user_agent TEXT,
    access_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_access_time (access_time)
);

CREATE TABLE IF NOT EXISTS performance_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(10,2) NOT NULL,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_metric_name (metric_name),
    INDEX idx_recorded_at (recorded_at)
);

-- Insert sample data
INSERT INTO users (username, email, password_hash) VALUES 
('admin', 'admin@example.com', SHA2('admin123', 256)),
('user1', 'user1@example.com', SHA2('user123', 256)),
('user2', 'user2@example.com', SHA2('user123', 256));

INSERT INTO performance_metrics (metric_name, metric_value) VALUES
('cpu_usage', 15.5),
('memory_usage', 45.2),
('disk_usage', 25.8),
('network_io', 102.3);

EOF

# Configure MySQL settings
cat > /etc/my.cnf.d/custom.cnf << 'EOF'
[mysqld]
# Basic settings
bind-address = 0.0.0.0
port = 3306
max_connections = 200
wait_timeout = 600
interactive_timeout = 600

# Performance tuning
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_log_buffer_size = 8M
innodb_flush_log_at_trx_commit = 1

# Logging
general_log = 1
general_log_file = /var/log/mysqld-general.log
log_error = /var/log/mysqld-error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysqld-slow.log
long_query_time = 2

# Security
local_infile = 0
skip_show_database

# Character set
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci

# Binary logging for replication (if needed)
server_id = 1
log_bin = /var/log/mysql-bin
binlog_format = ROW
expire_logs_days = 7
max_binlog_size = 100M

[mysql]
default_character_set = utf8mb4

[client]
default_character_set = utf8mb4
EOF

# Restart MySQL to apply configuration
systemctl restart mysqld

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/mysqld.log",
                        "log_group_name": "/aws/ec2/mysql/error",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/mysqld-general.log",
                        "log_group_name": "/aws/ec2/mysql/general",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/mysqld-slow.log",
                        "log_group_name": "/aws/ec2/mysql/slow",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "swap": {
                "measurement": [
                    "swap_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Configure log rotation for MySQL
cat > /etc/logrotate.d/mysql-custom << 'EOF'
/var/log/mysqld*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 mysql mysql
    postrotate
        /bin/systemctl reload mysqld.service > /dev/null 2>/dev/null || true
    endscript
}
EOF

# Set up database monitoring script
cat > /usr/local/bin/mysql-monitor.sh << 'EOF'
#!/bin/bash
# MySQL monitoring script
date
echo "=== MySQL Status ==="
mysql -u root -p"${mysql_root_password}" -e "SHOW GLOBAL STATUS LIKE 'Connections';"
mysql -u root -p"${mysql_root_password}" -e "SHOW GLOBAL STATUS LIKE 'Threads_connected';"
mysql -u root -p"${mysql_root_password}" -e "SHOW GLOBAL STATUS LIKE 'Threads_running';"
mysql -u root -p"${mysql_root_password}" -e "SHOW GLOBAL STATUS LIKE 'Questions';"
mysql -u root -p"${mysql_root_password}" -e "SHOW GLOBAL STATUS LIKE 'Uptime';"
echo "=== Database Sizes ==="
mysql -u root -p"${mysql_root_password}" -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.tables GROUP BY table_schema;"
echo "=================="
EOF

chmod +x /usr/local/bin/mysql-monitor.sh

# Add monitoring to cron
echo "*/5 * * * * /usr/local/bin/mysql-monitor.sh >> /var/log/mysql-monitor.log 2>&1" | crontab -

# Create database health check script
cat > /usr/local/bin/db-health-check.sh << 'EOF'
#!/bin/bash
# Database health check script
DB_STATUS=$(mysql -u root -p"${mysql_root_password}" -e "SELECT 1" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "Database is healthy"
    exit 0
else
    echo "Database is unhealthy"
    exit 1
fi
EOF

chmod +x /usr/local/bin/db-health-check.sh

# Set up automatic backup script
cat > /usr/local/bin/mysql-backup.sh << 'EOF'
#!/bin/bash
# MySQL backup script
BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql"

mkdir -p $BACKUP_DIR

# Create backup
mysqldump -u root -p"${mysql_root_password}" --all-databases --single-transaction --routines --triggers > $BACKUP_FILE

# Compress backup
gzip $BACKUP_FILE

# Remove backups older than 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

# Log backup completion
echo "$(date): Backup completed - backup_$DATE.sql.gz" >> /var/log/mysql-backup.log
EOF

chmod +x /usr/local/bin/mysql-backup.sh

# Schedule daily backup at 2 AM
echo "0 2 * * * /usr/local/bin/mysql-backup.sh" | crontab -

# Create performance monitoring stored procedure
mysql -u root -p"${mysql_root_password}" << EOF
USE ${mysql_database};

DELIMITER //
CREATE PROCEDURE GetPerformanceMetrics()
BEGIN
    SELECT 
        'connections' as metric_name,
        VARIABLE_VALUE as metric_value
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME = 'Connections'
    
    UNION ALL
    
    SELECT 
        'threads_connected' as metric_name,
        VARIABLE_VALUE as metric_value
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME = 'Threads_connected'
    
    UNION ALL
    
    SELECT 
        'queries_per_second' as metric_name,
        ROUND(VARIABLE_VALUE / (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME = 'Uptime'), 2) as metric_value
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME = 'Questions';
END//
DELIMITER ;
EOF

# Enable and start services
systemctl enable mysqld
systemctl start mysqld
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Configure firewall (if needed)
# firewall-cmd --permanent --add-port=3306/tcp
# firewall-cmd --reload

# Final message
echo "Database server setup completed successfully!"
echo "MySQL is running on port 3306"
echo "Database: ${mysql_database}"
echo "User: ${mysql_user}"
