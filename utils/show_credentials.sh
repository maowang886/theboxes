#!/bin/bash
# 查看已安装服务凭证

CRED_FILE="/root/.deploy_credentials.txt"
LOG_FILE="/var/log/theboxes/install.log"

if [ -f "$CRED_FILE" ]; then
    cat "$CRED_FILE"
    echo ""
    echo "========================================="
    echo "日志文件位置: $LOG_FILE"
else
    echo "未找到凭证文件，请先运行 selective_install.sh 部署服务。"
fi
