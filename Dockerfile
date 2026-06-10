# MLS 后端容器镜像
# 构建: docker build -t mls-backend:dev .
# 导出: docker save -o mls-backend.tar mls-backend:dev
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖（Pillow 等可能需要的运行时库）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg62-turbo \
    && rm -rf /var/lib/apt/lists/*

# 安装 Python 依赖
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 拷贝后端代码
COPY backend/ ./backend/

# 工作目录设为 backend/，使 uvicorn 能找到 main:app
WORKDIR /app/backend

# 暴露端口
EXPOSE 8000

# 启动（无 --reload，生产模式）
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
