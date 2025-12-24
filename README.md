# 重新构建镜像
./build-and-run.sh


# 运行容器 已经构建好的镜像spacewhisp/harness

```bash
docker run -d \
  -p 3000:3000 \
  -p 3022:3022 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/harness:/data \
  --name harness \
  --restart always \
  spacewhisp/harness:v4.0.0
```