#!/bin/bash

# 默认检查间隔
CHECK_INTERVAL=60
# 解析命令行参数
while getopts "t:" opt; do
  case $opt in
    t) CHECK_INTERVAL=$OPTARG ;;
  esac
done

# 安装目录
INSTALL_DIR="/root/c_n"
mkdir -p $INSTALL_DIR

# 创建检查脚本
cat <<EOF > $INSTALL_DIR/c_n.sh
#!/bin/bash
LOG_FILE="$INSTALL_DIR/error.log"

# 定义一个函数来获取当前时间戳
current_timestamp() {
    echo \$(date +"%Y-%m-%d %H:%M:%S")
}

function check_nginx {
    if ! command -v nginx &> /dev/null; then
        echo "\$(current_timestamp) - Nginx is not installed" >> \$LOG_FILE
        return 1
    fi

    # 检查nginx状态和日志
    if systemctl is-active --quiet nginx; then
        echo "\$(current_timestamp) - Nginx is running"
        # 检查是否有PID文件解析失败的错误
        if journalctl -u nginx --since "1 hour ago" | grep -q "Failed to parse PID from file /run/nginx.pid: Invalid argument"; then
            echo "\$(current_timestamp) - Detected PID file parse error. Attempting to fix..." >> \$LOG_FILE
            # 尝试修复PID文件解析问题
            systemctl stop nginx
            rm -f /run/nginx.pid
            systemctl start nginx
            if [ \$? -ne 0 ]; then
                echo "\$(current_timestamp) - Failed to restart Nginx after attempting to fix PID file issue" >> \$LOG_FILE
            else
                echo "\$(current_timestamp) - Nginx restarted successfully after fixing PID file issue."
            fi
        fi
    else
        echo "\$(current_timestamp) - Nginx is not running. Starting Nginx..."
        systemctl start nginx
        if [ \$? -ne 0 ]; then
            echo "\$(current_timestamp) - Failed to start Nginx" >> \$LOG_FILE
        fi
    fi
}

while true; do
    check_nginx
    sleep $CHECK_INTERVAL
done
EOF

chmod +x $INSTALL_DIR/c_n.sh

# 创建 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/c_n.service"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Nginx Checker Service

[Service]
ExecStart=$INSTALL_DIR/c_n.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置，启用并启动服务
systemctl daemon-reload

# 检查服务是否存在，并替换旧服务
if systemctl --quiet is-active c_n; then
    systemctl stop c_n
fi
systemctl enable c_n
systemctl start c_n

echo "Nginx check service installed and started."
