#!/bin/bash

# Harness Docker 镜像构建和运行脚本

set -e

IMAGE_NAME="harness:local"
CONTAINER_NAME="harness"

echo "=========================================="
echo "开始构建 Harness Docker 镜像..."
echo "=========================================="

# 构建镜像
if ! docker build -t ${IMAGE_NAME} .; then
    echo ""
    echo "❌ 镜像构建失败！"
    echo ""
    echo "可能的原因："
    echo "1. 无法访问 Docker Hub（网络问题）"
    echo "2. 请检查网络连接或配置 Docker 镜像加速器"
    echo ""
    echo "解决方案请参考: DOCKER_BUILD_GUIDE.md"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ 镜像构建完成！"
echo "=========================================="

# 检查是否已有同名容器在运行
if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo ""
    echo "检测到已存在的容器 ${CONTAINER_NAME}"
    read -p "是否要停止并删除现有容器？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "停止并删除现有容器..."
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
    else
        echo "保留现有容器，退出脚本"
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo "创建并启动容器..."
echo "=========================================="

# 创建并运行容器
docker run -d \
  -p 3000:3000 \
  -p 3022:3022 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/harness:/data \
  --name ${CONTAINER_NAME} \
  --restart always \
  ${IMAGE_NAME}

echo ""
echo "=========================================="
echo "✅ 容器已启动！"
echo "=========================================="
echo ""
echo "访问信息："
echo "  🌐 Web UI: http://localhost:3000"
echo "  🔌 SSH 端口: 3022"
echo ""
echo "常用命令："
echo "  查看容器状态: docker ps -a | grep ${CONTAINER_NAME}"
echo "  查看容器日志: docker logs -f ${CONTAINER_NAME}"
echo "  停止容器: docker stop ${CONTAINER_NAME}"
echo "  删除容器: docker rm ${CONTAINER_NAME}"
echo ""
