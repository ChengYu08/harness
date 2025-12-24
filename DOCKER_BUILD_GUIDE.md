# Harness Docker 镜像构建指南

## 问题说明

如果遇到网络连接问题（无法访问 Docker Hub），请按照以下步骤解决：

## 解决方案

### 方案一：配置 Docker 镜像加速器（推荐）

#### macOS Docker Desktop

1. 打开 Docker Desktop
2. 点击设置图标（齿轮）
3. 进入 **Docker Engine** 设置
4. 在 JSON 配置中添加以下内容：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

5. 点击 **Apply & Restart** 重启 Docker

#### Linux 系统

编辑 `/etc/docker/daemon.json` 文件：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 方案二：使用代理

如果您的网络需要通过代理访问外网，请配置 Docker 代理：

#### macOS Docker Desktop

1. 打开 Docker Desktop
2. 进入 **Resources** > **Proxies**
3. 配置 HTTP/HTTPS 代理

#### Linux 系统

创建或编辑 `/etc/systemd/system/docker.service.d/http-proxy.conf`：

```ini
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"
Environment="NO_PROXY=localhost,127.0.0.1"
```

然后重启 Docker：
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 构建和运行步骤

### 1. 构建镜像

```bash
cd /Users/yucheng/Desktop/code/harness
docker build -t harness:local .
```

### 2. 检查并停止已存在的容器（可选）

```bash
# 停止并删除已存在的容器
docker stop harness 2>/dev/null || true
docker rm harness 2>/dev/null || true
```

### 3. 创建并运行容器

```bash
docker run -d \
  -p 3000:3000 \
  -p 3022:3022 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/harness:/data \
  --name harness \
  --restart always \
  harness:local
```

### 4. 验证容器运行

```bash
# 查看容器状态
docker ps | grep harness

# 查看容器日志
docker logs -f harness

# 访问 Web UI
# 浏览器打开: http://localhost:3000
```

## 一键脚本

创建 `build-and-run.sh` 文件：

```bash
#!/bin/bash

set -e

IMAGE_NAME="harness:local"
CONTAINER_NAME="harness"

echo "开始构建镜像..."
docker build -t ${IMAGE_NAME} .

if [ "$(docker ps -aq -f name=${CONTAINER_NAME})" ]; then
    echo "停止并删除现有容器..."
    docker stop ${CONTAINER_NAME} 2>/dev/null || true
    docker rm ${CONTAINER_NAME} 2>/dev/null || true
fi

echo "创建并启动容器..."
docker run -d \
  -p 3000:3000 \
  -p 3022:3022 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/harness:/data \
  --name ${CONTAINER_NAME} \
  --restart always \
  ${IMAGE_NAME}

echo "容器已启动！访问 http://localhost:3000"
```

然后执行：
```bash
chmod +x build-and-run.sh
./build-and-run.sh
```

## 故障排查

### 检查网络连接

```bash
# 测试 Docker Hub 连接
docker pull alpine:latest

# 如果失败，检查 DNS
ping registry-1.docker.io
```

### 检查 Docker 配置

```bash
# 查看 Docker 信息
docker info

# 查看 Docker 版本
docker version
```

### 清理构建缓存（如果构建失败）

```bash
docker builder prune -a
```

## 注意事项

- **数据持久化**：容器使用 `/tmp/harness` 目录存储数据，建议使用命名卷：
  ```bash
  docker volume create harness-data
  # 然后使用 -v harness-data:/data
  ```

- **Docker API 版本**：Dockerfile 中已设置为 `1.44`（第86行）

- **端口映射**：
  - `3000`：Web UI 和 REST API
  - `3022`：SSH 服务

- **资源要求**：构建过程可能需要较长时间和较多资源，请确保有足够的磁盘空间和内存

