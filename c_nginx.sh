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
