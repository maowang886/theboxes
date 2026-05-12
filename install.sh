#!/bin/bash
# 极简安装器 - 无需任何预装知识

# 颜色输出（如果 tput 不可用则跳过）
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}>>> 百宝箱安装器 <<<${NC}"

# 1. 确保基础工具可用
if ! command -v git &> /dev/null; then
    echo "需要安装 git，正在尝试..."
    apt update && apt install -y git curl wget
fi

# 2. 克隆仓库（如果已存在则更新）
REPO_DIR="theboxes"
if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR" && git pull
else
    git clone https://github.com/maowang886/theboxes.git
    cd "$REPO_DIR"
fi

# 3. 给所有脚本加权
chmod +x selective_install.sh utils/*.sh 2>/dev/null

# 4. 运行主脚本
sudo bash selective_install.sh
