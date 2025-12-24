#!/bin/bash

# Harness Docker 镜像构建和运行脚本（支持多平台）

set -e

IMAGE_NAME="harness:v3.0.0"
CONTAINER_NAME="harness"

# 检测当前系统架构
CURRENT_ARCH=$(uname -m)
case $CURRENT_ARCH in
    x86_64)
        CURRENT_PLATFORM="linux/amd64"
        ;;
    arm64|aarch64)
        CURRENT_PLATFORM="linux/arm64"
        ;;
    *)
        CURRENT_PLATFORM="linux/amd64"
        echo "⚠️  未知的架构 ${CURRENT_ARCH}，默认使用 linux/amd64"
        ;;
esac

# 解析命令行参数
BUILD_PLATFORMS=""
MULTI_PLATFORM=false
RUN_CONTAINER=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            BUILD_PLATFORMS="$2"
            shift 2
            ;;
        --multi-platform)
            MULTI_PLATFORM=true
            BUILD_PLATFORMS="linux/amd64,linux/arm64"
            shift
            ;;
        --no-run)
            RUN_CONTAINER=false
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --platform PLATFORM    指定构建平台 (例如: linux/amd64, linux/arm64)"
            echo "  --multi-platform       构建多平台镜像 (linux/amd64,linux/arm64)"
            echo "  --no-run               只构建镜像，不运行容器"
            echo "  -h, --help             显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0                      # 构建当前平台镜像并运行"
            echo "  $0 --platform linux/amd64  # 构建指定平台镜像"
            echo "  $0 --multi-platform     # 构建多平台镜像"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 如果没有指定平台，使用当前平台
if [ -z "$BUILD_PLATFORMS" ]; then
    BUILD_PLATFORMS="$CURRENT_PLATFORM"
fi

echo "=========================================="
echo "开始构建 Harness Docker 镜像..."
echo "=========================================="
echo "构建平台: ${BUILD_PLATFORMS}"
echo "当前系统: ${CURRENT_PLATFORM}"
echo ""

# 检查并创建 buildx builder（如果需要多平台构建）
if [ "$MULTI_PLATFORM" = true ] || [[ "$BUILD_PLATFORMS" == *","* ]]; then
    echo "准备多平台构建环境..."
    if ! docker buildx ls | grep -q "multiarch"; then
        echo "创建 buildx builder..."
        docker buildx create --name multiarch --use 2>/dev/null || docker buildx use multiarch 2>/dev/null || true
    else
        docker buildx use multiarch 2>/dev/null || true
    fi
    docker buildx inspect --bootstrap >/dev/null 2>&1 || true
fi

# 构建镜像
BUILD_CMD=""
if [ "$MULTI_PLATFORM" = true ] || [[ "$BUILD_PLATFORMS" == *","* ]]; then
    # 多平台构建
    if [ "$RUN_CONTAINER" = true ]; then
        # 如果需要运行容器，只能加载单个平台（Docker 限制）
        echo "⚠️  多平台构建模式：由于 Docker 限制，--load 只能加载单个平台"
        echo "   将构建并加载当前平台 (${CURRENT_PLATFORM}) 用于运行"
        echo "   提示：要使用完整的多平台镜像，请推送到 registry："
        echo "   docker buildx build --platform ${BUILD_PLATFORMS} --push -t <registry>/harness:tag ."
        BUILD_CMD="docker buildx build --platform ${CURRENT_PLATFORM} --load -t ${IMAGE_NAME} ."
    else
        # 只构建不运行，构建所有平台但不 load（需要推送到 registry）
        echo "⚠️  多平台构建模式：构建所有平台，但不加载到本地"
        echo "   提示：多平台镜像需要推送到 registry 才能使用"
        echo "   示例：docker buildx build --platform ${BUILD_PLATFORMS} --push -t <registry>/harness:tag ."
        BUILD_CMD="docker buildx build --platform ${BUILD_PLATFORMS} -t ${IMAGE_NAME} ."
    fi
else
    # 单平台构建
    BUILD_CMD="docker build --platform ${BUILD_PLATFORMS} -t ${IMAGE_NAME} ."
fi

echo "执行构建命令: ${BUILD_CMD}"
echo ""

if ! eval ${BUILD_CMD}; then
    echo ""
    echo "❌ 镜像构建失败！"
    echo ""
    echo "可能的原因："
    echo "1. 无法访问 Docker Hub（网络问题）"
    echo "2. 请检查网络连接或配置 Docker 镜像加速器"
    echo "3. 平台不支持或缺少必要的构建工具"
    echo ""
    echo "解决方案请参考: DOCKER_BUILD_GUIDE.md"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ 镜像构建完成！"
echo "=========================================="

# 如果设置了 --no-run，则跳过容器运行
if [ "$RUN_CONTAINER" = false ]; then
    echo ""
    echo "镜像构建完成，跳过容器运行（使用了 --no-run 选项）"
    exit 0
fi

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

# 创建并运行容器（使用当前平台）
docker run -d \
  --platform ${CURRENT_PLATFORM} \
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
echo "构建信息："
echo "  镜像名称: ${IMAGE_NAME}"
echo "  构建平台: ${BUILD_PLATFORMS}"
echo "  运行平台: ${CURRENT_PLATFORM}"
if [ "$MULTI_PLATFORM" = true ] || [[ "$BUILD_PLATFORMS" == *","* ]]; then
    echo "  构建模式: 多平台"
fi
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
echo "多平台镜像管理："
echo "  查看镜像平台: docker buildx imagetools inspect ${IMAGE_NAME}"
echo "  构建并推送到 registry: docker buildx build --platform linux/amd64,linux/arm64 --push -t <registry>/harness:tag ."
echo ""
