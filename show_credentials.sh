#!/bin/bash
# 查看已安装服务的凭证

CRED_FILE="/root/.deploy_credentials.txt"

if [ -f "$CRED_FILE" ]; then
    cat "$CRED_FILE"
else
    echo "未找到凭证文件，请先运行 selective_install.sh 部署服务。"
fi
