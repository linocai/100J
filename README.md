# 100J

100J 是跑在 Apple 设备上的私有云事务 OS。后端 FastAPI + PostgreSQL，
客户端 SwiftUI (macOS / iOS) 共用一份 `PersonalAffairsCore` 处理 API、
模型、仓储与离线队列。

## 运行

后端：

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
uvicorn app.main:app --reload
```

详细环境变量与生产部署见 [`deployment.md`](deployment.md)。

Apple 客户端：

```bash
cd frontend/apple
swift build
swift test
```

macOS 打包：

```bash
frontend/apple/scripts/package-macos-app.sh
```

iOS 走 `frontend/apple/PersonalAffairsApp.xcodeproj`，详见
[`frontend/apple/README.md`](frontend/apple/README.md)。

## 仓库结构

```text
backend/                       # FastAPI + SQLAlchemy + Alembic
frontend/apple/                # SwiftUI macOS / iOS（共用 PersonalAffairsCore）
scripts/                       # 部署、生产检查、备份
deployment.md                  # HZ 生产部署指南
docker-compose.yml             # 本地 Postgres 等开发容器
```

## 开发规约

- 客户端跨平台共享规则：[`frontend/apple/SHARING_RULES.md`](frontend/apple/SHARING_RULES.md)
