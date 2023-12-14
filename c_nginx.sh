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
INSTALL_DIR="/root/nginx-checker"
mkdir -p $INSTALL_DIR

# 创建检查脚本
cat <<EOF > $INSTALL_DIR/check-nginx.sh
#!/bin/bash
LOG_FILE="$INSTALL_DIR/error.log"

function check_nginx {
    if ! command -v nginx &> /dev/null; then
        echo "Nginx is not installed" >> \$LOG_FILE
        return 1
    fi

    if systemctl is-active --quiet nginx; then
        echo "Nginx is running"
    else
        echo "Nginx is not running. Starting Nginx..."
        systemctl start nginx
        if [ \$? -ne 0 ]; then
            echo "Failed to start Nginx" >> \$LOG_FILE
        fi
    fi
}

while true; do
    check_nginx
    sleep $CHECK_INTERVAL
done
EOF

chmod +x $INSTALL_DIR/check-nginx.sh

# 创建 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/nginx-checker.service"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Nginx Checker Service

[Service]
ExecStart=$INSTALL_DIR/check-nginx.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置，启用并启动服务
systemctl daemon-reload

# 检查服务是否存在，并替换旧服务
if systemctl --quiet is-active nginx-checker; then
    systemctl stop nginx-checker
fi
systemctl enable nginx-checker
systemctl start nginx-checker

echo "Nginx check service installed and started."
