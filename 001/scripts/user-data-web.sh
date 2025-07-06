#!/bin/bash

# ========================================
# Web Server Setup Script
# Amazon Linux 2 - Apache + PHP + CloudWatch Agent
# ========================================

# Update system
yum update -y

# Install required packages
yum install -y \
    httpd \
    php \
    php-mysqlnd \
    php-json \
    php-mbstring \
    php-xml \
    php-curl \
    mysql \
    amazon-cloudwatch-agent \
    awslogs \
    htop \
    git \
    unzip

# Configure Apache
systemctl start httpd
systemctl enable httpd

# Create web directory and set permissions
mkdir -p /var/www/html
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create a simple PHP info page
cat > /var/www/html/info.php << 'EOF'
<?php
phpinfo();
?>
EOF

# Create a database connection test page
cat > /var/www/html/dbtest.php << 'EOF'
<?php
$servername = "${db_host}";
$username = "${db_user}";
$password = "${db_password}";
$dbname = "${db_name}";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    echo "<h1>Database Connection Successful!</h1>";
    echo "<p>Connected to database: $dbname</p>";
    echo "<p>Server: $servername</p>";
    
    // Test query
    $stmt = $pdo->query("SELECT VERSION() as version");
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p>MySQL Version: " . $result['version'] . "</p>";
    
} catch(PDOException $e) {
    echo "<h1>Database Connection Failed!</h1>";
    echo "<p>Error: " . $e->getMessage() . "</p>";
}
?>
EOF

# Create a simple web application
cat > /var/www/html/index.php << 'EOF'
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAMP Infrastructure Demo</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .info-box {
            background-color: #e8f4f8;
            border: 1px solid #bee5eb;
            border-radius: 5px;
            padding: 15px;
            margin: 10px 0;
        }
        .status {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 3px;
            color: white;
            font-weight: bold;
        }
        .success { background-color: #28a745; }
        .warning { background-color: #ffc107; color: #212529; }
        .error { background-color: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 LAMP Infrastructure Demo</h1>
        
        <div class="info-box">
            <h3>システム情報</h3>
            <p><strong>Server:</strong> <?php echo gethostname(); ?></p>
            <p><strong>Server IP:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?></p>
            <p><strong>PHP Version:</strong> <?php echo phpversion(); ?></p>
            <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
        </div>
        
        <div class="info-box">
            <h3>データベース接続テスト</h3>
            <?php
            $db_host = "${db_host}";
            $db_user = "${db_user}";
            $db_password = "${db_password}";
            $db_name = "${db_name}";
            
            try {
                $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_password);
                $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
                echo '<span class="status success">✓ 接続成功</span>';
                echo "<p>データベース: $db_name</p>";
                
                // Create test table if not exists
                $pdo->exec("CREATE TABLE IF NOT EXISTS access_log (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    ip_address VARCHAR(45),
                    user_agent TEXT,
                    access_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )");
                
                // Insert access log
                $stmt = $pdo->prepare("INSERT INTO access_log (ip_address, user_agent) VALUES (?, ?)");
                $stmt->execute([$_SERVER['REMOTE_ADDR'], $_SERVER['HTTP_USER_AGENT']]);
                
                // Get access count
                $stmt = $pdo->query("SELECT COUNT(*) as count FROM access_log");
                $result = $stmt->fetch(PDO::FETCH_ASSOC);
                echo "<p>総アクセス数: " . $result['count'] . "</p>";
                
            } catch(PDOException $e) {
                echo '<span class="status error">✗ 接続失敗</span>';
                echo "<p>エラー: " . $e->getMessage() . "</p>";
            }
            ?>
        </div>
        
        <div class="info-box">
            <h3>Load Balancer Test</h3>
            <p>このページにアクセスすることで、ALBが正常に動作していることを確認できます。</p>
            <p>リロードするとランダムなサーバーにアクセスされます。</p>
            <p><strong>Instance ID:</strong> <?php echo file_get_contents('http://169.254.169.254/latest/meta-data/instance-id'); ?></p>
        </div>
        
        <div class="info-box">
            <h3>リンク</h3>
            <ul>
                <li><a href="/info.php">PHP情報</a></li>
                <li><a href="/dbtest.php">データベーステスト</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

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
                        "file_path": "/var/log/httpd/access_log",
                        "log_group_name": "/aws/ec2/httpd/access",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/httpd/error_log",
                        "log_group_name": "/aws/ec2/httpd/error",
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

# Configure log rotation
cat > /etc/logrotate.d/httpd-custom << 'EOF'
/var/log/httpd/*log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 apache apache
    postrotate
        /bin/systemctl reload httpd.service > /dev/null 2>/dev/null || true
    endscript
}
EOF

# Set up system monitoring script
cat > /usr/local/bin/system-monitor.sh << 'EOF'
#!/bin/bash
# System monitoring script
date
echo "=== System Status ==="
echo "CPU Usage: $(top -bn1 | grep load | awk '{printf "%.2f%%", $(NF-2)}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.2f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
echo "Active Connections: $(netstat -an | grep :80 | wc -l)"
echo "====================="
EOF

chmod +x /usr/local/bin/system-monitor.sh

# Add monitoring to cron
echo "*/5 * * * * /usr/local/bin/system-monitor.sh >> /var/log/system-monitor.log 2>&1" | crontab -

# Enable and start services
systemctl enable httpd
systemctl start httpd
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Create health check endpoint
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');
$status = 'healthy';
$checks = [];

// Check Apache
$checks['apache'] = (shell_exec('pgrep httpd') != '') ? 'ok' : 'error';

// Check disk space
$disk_usage = shell_exec("df / | tail -1 | awk '{print $5}' | sed 's/%//'");
$checks['disk'] = ($disk_usage < 90) ? 'ok' : 'warning';

// Check memory
$memory_usage = shell_exec("free | grep Mem | awk '{printf \"%.1f\", $3/$2 * 100.0}'");
$checks['memory'] = ($memory_usage < 90) ? 'ok' : 'warning';

// Overall status
foreach ($checks as $check) {
    if ($check === 'error') {
        $status = 'unhealthy';
        break;
    }
}

echo json_encode([
    'status' => $status,
    'timestamp' => date('c'),
    'checks' => $checks,
    'instance' => gethostname()
]);
?>
EOF

# Final message
echo "Web server setup completed successfully!"
echo "Access http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"
