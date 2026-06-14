# MLS 故障定位手册

> 按「症状 → 先查哪个文件 → 怎么确认 → 怎么修」组织。
> 所有路径相对于仓库根 `C:\projects\mls`。

---

## 1. App 连不上后端

**症状**：Flutter App 启动后白屏、Network Error、或请求超时。

**诊断路径**：

1. 确认后端是否在跑
   ```powershell
   curl http://192.168.0.105:8000/
   # 预期: {"service":"MLS 后端","status":"running",...}
   ```
   如果 curl 也连不上 → 后端没启动或 IP 不对。

2. 检查电脑 IP 是否变更
   ```powershell
   ipconfig | findstr "IPv4"
   ```
   如果 IP 变了 → 更新 `app/mls_app/lib/config/api_config.dart` 中的默认值，
   或启动时用 `--dart-define=API_BASE_URL=http://新IP:8000` 覆盖。

3. 检查防火墙
   - Windows 防火墙可能拦截 8000 端口入站
   - 临时测试：关闭防火墙后重试
   - 永久解决：添加入站规则允许 8000 端口

4. 模拟器特殊处理
   - Android 模拟器内 `localhost` = 模拟器自身
   - 必须用 `10.0.2.2` 访问宿主机
   - 启动命令：`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`

**相关文件**：
- `app/mls_app/lib/config/api_config.dart` — `baseUrl` 默认值
- `backend/main.py:247` — `GET /` 健康检查

---

## 2. 登录后莫名 401 或反复跳登录页

**症状**：已登录用户偶尔被踢回登录页，或操作中突然 401。

**诊断路径**：

1. 检查 refresh token 是否被黑名单
   - refresh token 使用后立即被黑名单（`main.py:190-200`）
   - 如果多个设备共用同一账号，refresh 互相踢

2. 检查 `api_client.dart` 拦截器时序
   ```
   请求 → 401 → _isRefreshing?
     ├─ true → 入队 _pendingQueue
     └─ false → POST /auth/refresh
                  ├─ 成功 → 存新 token → 重放
                  └─ 失败 → 清 storage → context.go('/login')
   ```
   - 关键日志：看 `LogInterceptor` 输出中 `/auth/refresh` 的响应
   - 如果 refresh 本身返回 401 → refresh token 过期或已被黑名单

3. 检查 fakeredis 状态
   - fakeredis 在内存中，后端重启后所有黑名单丢失
   - 效应：后端重启后旧 refresh token 仍然有效（安全降级，可接受）

**相关文件**：
- `app/mls_app/lib/services/api_client.dart` — 401 拦截器（line 57-105）
- `backend/main.py:206-232` — `get_current_agent` 鉴权依赖
- `backend/main.py:190-200` — refresh 黑名单逻辑

---

## 3. 照片上传 413 / 415 / 500

**症状**：照片上传返回 HTTP 错误码。

**诊断路径**：

| 状态码 | 含义 | 触发位置 | 检查方法 |
|---|---|---|---|
| **415** | 不支持的图片格式 | `photos.py:39-43` | 确认文件是 JPEG 或 PNG，content_type 必须是 `image/jpeg` 或 `image/png` |
| **413** | 文件过大 | `photos.py:49-53` | 单张照片上限 5MB（`MAX_FILE_SIZE = 5*1024*1024`），压缩或降低分辨率 |
| **500** | MinIO 不可达 | `storage.py:70-77` | 见第 4 节「MinIO 不可达」|

**相关文件**：
- `backend/photos.py` — `upload_photo_endpoint`（line 31-57）
- `backend/storage.py` — `upload_photo`（line 58-77）

---

## 4. MinIO 不可达

**症状**：
- 后端起得来，但上传照片返回 500
- 控制台出现 `[storage] ensure_bucket failed (MinIO may be down)`

**诊断路径**：

1. 确认 MinIO 服务是否在 NAS 上运行
   ```powershell
   curl http://192.168.0.200:9000
   # MinIO 会返回 XML 格式的 AccessDenied（正常 — 说明服务在）
   ```

2. 检查环境变量
   ```powershell
   # 确认这些值指向正确的 MinIO 实例
   $env:MINIO_ENDPOINT   # 应 = 192.168.0.200:9000
   $env:MINIO_ACCESS_KEY
   $env:MINIO_SECRET_KEY
   ```

3. 确认 bucket 存在
   - 访问 MinIO WebUI：`http://192.168.0.200:9001`
   - 检查 `mls-photos` bucket 是否存在
   - 如果不存在：MinIO 启动后 `ensure_bucket()` 会自动创建（开发期只打 warning）

**设计意图**：`ensure_bucket()` 在 startup 事件中失败只打 warning，不阻止启动。
这样开发时没起 MinIO 也能正常跑后端（只是上传照片会报 500）。

**相关文件**：
- `backend/storage.py` — `ensure_bucket()`（line 43-55）
- `backend/config.py` — MinIO 系列环境变量（line 32-38）

---

## 5. 后端起不来

**症状**：`uvicorn main:app` 报错退出。

**诊断路径**：

| 原因 | 错误信息 | 检查方法 |
|---|---|---|
| Python 依赖缺失 | `ModuleNotFoundError: No module named 'xxx'` | `pip install -r requirements.txt` |
| Mongo 连不上 | `❌ MongoDB 连接失败` | `curl mongodb://localhost:27017` 或用 `mongosh` 测试 |
| 端口 8000 被占用 | `Address already in use` | `netstat -ano | findstr 8000` → `taskkill /PID xxx` |
| 环境变量缺失 | 后端依赖都有默认值，不会因此挂 | 仅 MinIO 功能受影响 |

**启动验证**：
```powershell
cd C:\projects\mls\backend
.\venv\Scripts\activate
python -c "import main; print('OK')"
```

---

## 6. 日志位置

| 日志类型 | 位置 | 说明 |
|---|---|---|
| uvicorn 请求日志 | 控制台 stdout | 每个 HTTP 请求一行，含状态码 |
| Dio 请求日志 | Flutter 控制台 | `LogInterceptor` 输出 request/response body |
| MinIO 日志 | 控制台 stdout | `[storage]` 前缀的 logging 消息 |
| MongoDB ping | 控制台 stdout | startup 时 `[OK] MongoDB connected` 或 `[FAIL]` |

如需更多日志，在 `main.py` 中添加 `print()` 或 `logging.info()`（项目当前未集成 logging 框架）。

---

## 附录 A：部署步骤

```bash
# 1. 构建镜像
cd C:\projects\mls
docker build -t mls-backend:dev .

# 2. 导出镜像
docker save -o mls-backend.tar mls-backend:dev

# 3. 拷贝到 NAS
scp mls-backend.tar user@192.168.0.200:/path/to/deploy/

# 4. NAS 上加载镜像
docker load -i mls-backend.tar

# 5. 迁库（如果初次部署需要迁移 MongoDB 数据）
mongodump --uri="mongodb://旧机器:27017" --db=mls_zhangjiakou --out=dump/
mongorestore --uri="mongodb://192.168.0.200:27017" dump/

# 6. 更换 SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"
# 将输出值设为 NAS 上的环境变量 SECRET_KEY

# 7. 启动容器
docker run -d -p 8000:8000 --name mls-backend \
  -e MONGO_URI=mongodb://192.168.0.200:27017 \
  -e SECRET_KEY=<新生成的随机值> \
  -e MINIO_ENDPOINT=192.168.0.200:9000 \
  -e MINIO_ACCESS_KEY=minioadmin \
  -e MINIO_SECRET_KEY=minioadmin \
  -e DEV_SMS_CODE=123456 \
  mls-backend:dev
```

> Docker Compose 中 backend 块当前被注释，待 NAS 环境验证后启用。
> 启用后上述 docker run 命令可替换为 `docker compose up -d`。

---

## 附录 B：已知技术债

### 高优先级
- [ ] **COS / MinIO 迁移** — 照片从 MongoDB base64 → MinIO（旧 base64 不回迁，双轨共存）
- [ ] **真实短信接入** — 替换 `DEV_SMS_CODE` 硬编码
- [ ] **MongoDB 每日备份** — mongodump + cron / 定时任务
- [ ] **MinIO 备份** — bucket mirror 或定期 rsync

### 中优先级
- [ ] **SECRET_KEY 轮换** — 已进 git 历史，NAS 部署时必须换
- [ ] **审计日志** — 关键操作（挂牌/成交/结算）缺少操作日志
- [ ] **客户资产化改造** — 客户关联房源→带看→成交全链路
- [ ] **WebSocket/SSE 实时推送** — 待办角标、协作状态变更通知
- [ ] **pre-commit hook: flutter analyze** — 防止 lint 劣化

### TODO(prod) 假数据清单

运行 `grep -rn "TODO(prod)" app/mls_app/lib/` 可查最新：

| 文件 | 行号 | 内容 |
|---|---|---|
| `home_screen.dart` | 51 | `_unreadCount = 3` mock 未读数 |
| `customer_detail_screen.dart` | 183 | `_buildMatchingListings` 匹配房源 mock |
| `customer_detail_screen.dart` | 250 | `_defaultFollowups` 跟进记录 mock |
| `listing_detail_screen.dart` | 523 | `'本房源由我挂牌 · 信誉 A · 成交 23'` mock 文案 |
| `chat_screen.dart` | 79 | `_seedMessages` 全部种子消息 |
| `chat_screen.dart` | 114 | `'好的，收到👍'` 自动回复 mock |
