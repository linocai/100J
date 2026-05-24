# 100J v1.2.4 项目规划

> 这是 100J 仓库**第一份** PROJECT_PLAN。本版聚焦"把 v1.2.3 独立 reviewer 审出的 34 条问题全部修干净"，不引入任何新业务能力。
>
> 工作目录 `/Users/linotsai/Lino/100%J/`，基线 commit `4d42f44`（v1.2.3 / build 1.125），目标 commit 标签 `v1.2.4`（build 1.126）。

---

## 1. 概述

### 1.1 目标

- 修复 reviewer 列出的 **34 条**问题（4 致命 / 15 重要 / 15 建议）。
- 不引入新业务能力、不改 OpenAPI 已有契约（仅**新增** endpoint，且都向后兼容）。
- 单用户私有云定位保持不变：owner 一人用，prod 关闭公共注册口。

### 1.2 覆盖范围

| 类别 | 总数 | v1.2.4 修复 | 延后到 v1.2.5+ |
| --- | --- | --- | --- |
| 致命（红） | 4 | 4 | 0 |
| 重要（黄） | 15 | 13 | 2（#14 keyset 分页、#17 Alembic 重写） |
| 建议（蓝） | 15 | 15 | 0 |
| **合计** | **34** | **32** | **2** |

延后理由见 §6。

### 1.3 预估周期

- 7 个 phase，按依赖串行 + 局部并行，单人节奏 **5–6 个工作日**。
- 不含 prod 部署观察窗（建议合并后 dev 跑 2 天再发布）。

### 1.4 Release Criteria

下列条件**全部**满足才能打 v1.2.4 tag：

1. 全部 32 条问题对应的代码改动已合入 `main`，每条都能在 commit message 或 PR 描述中追到。
2. `pytest -q` 后端全绿，新增/修改用例参见各 phase 测试计划。
3. `xcodebuild -scheme PersonalAffairsApp -destination 'platform=macOS' test` 与 iOS Simulator 同款命令均绿。
4. `scripts/verify-release.sh` 跑通（lint + 单测 + OpenAPI snapshot）。
5. `scripts/prod-check.sh` 在 HZ 云灰度环境跑通。
6. **手测**清单全过（§7.3）。
7. `MARKETING_VERSION = 1.2.4` + `CURRENT_PROJECT_VERSION = 1.126` 双 target 同步提升。
8. `deployment.md` 末尾追加 v1.2.4 改动摘要 + 回滚步骤指针。

---

## 2. 依赖图

### 2.1 Phase 全景

```
P0 基础设施加固 (settings + rate_limit + main.py + email_sender)
  ├─→ P1 Device session 刷新链路修复 (致命 #1 / #6 / #8 / #12 / #25)
  │     └─→ P2 注册/登录入口收口 (#5 / #19 / #18 / #16 / #20)
  ├─→ P3 Apple Sign-In 安全 + 死代码取舍 (#2 / #11 / #13)
  ├─→ P4 Calendar 半天/全天字段一致性 (#4 / #22 / #23)
  ├─→ P5 Agent 并发 + 加密 + UI 补口 (#10 / #15 / #32 / #34)
  └─→ P6 客户端鲁棒性 + Widget (#3 / #9 / #21 / #26 / #27 / #28 / #29 / #31 / #33)

  P7 发布工程 (#30 + 版本号 + 回滚预案 + 文档)
```

### 2.2 关键依赖（"X 修了 Y 才有意义"）

| 前置 | 后续 | 原因 |
| --- | --- | --- |
| P0 settings 加强 | P2 #19 refresh rotation、P3 #15 scrypt 派生 | rotation/派生都需要新 settings 字段（最小长度、jti TTL） |
| P1 #1 device-refresh 走通 | #12 401 闪烁缓解、#8 ResumingPlaceholder 死锁解除 | 一旦 401 能自愈，前端再也不会反复打"已失效"提示 |
| P3 决策（删 vs 补全 Apple Sign-In） | #2 后端 email_hint 收紧、#13 前端死代码 | 必须先定方向再动代码 |
| P0 rate_limit 加 proxy-headers | P2 #5 / #6 / #16 / #20 限流真实生效 | 不修 IP 透传，所有限流都是 127.0.0.1 共享配额 |
| P4 Calendar 全天/有时字段后端清字段 | 前端 422 静默修复 | 后端兜底是主线方案，前端 encoder 补丁是次方案 |
| Alembic 是否动 0001（#17） | P2 写 jti 黑名单 / refresh rotation 表 | 决定新表用新版本（0006_xxx）的方式接入，不动 0001 |

### 2.3 强制顺序（依次执行）

```
P0 → P1 → P2 ↘
         P3 ↗  → P5 → P6 → P7
         P4 ↗
```

P3 / P4 在 P2 完成后可与 P5 并行，但都要先于 P6 完成（P6 客户端会动到 Auth 入口和 entitlement）。

---

## 3. 不在 v1.2.4 范围（deferred）

> 这两条**故意不做**，理由如下，请在 v1.2.5 排期。

### Deferred-A：#14 分页 cursor 改 keyset

- **问题**：当前 `paginate()` 用 `offset/limit`，并发增删会漏行/重复。
- **不做理由**：
  - 改动面波及全部 list endpoints（tasks / projects / notes / calendar / agent_logs / spaces）+ 前端 `fetchAll` 的 cursor 解析。
  - 单用户私有云，实际并发=0（owner 一个人手指头按不出竞态）；漏行风险**极低**。
  - 真要修，得改成 keyset（按 `(updated_at, id)`）+ 写 Migration 给 `agent_action_log.created_at` 加复合索引，要单独一个 release 验证回滚。
- **替代缓解**：在 v1.2.4 给 `paginate()` 加单元测试覆盖 "limit=1 翻页 3 次拿到 3 条不同行"，**记录已知问题**到 `backend/README.md` "Known Limitations" 段。

### Deferred-B：#17 Alembic 0001 改成显式 `op.create_table`

- **问题**：当前 0001 用 `Base.metadata.create_all`，未来 model 漂移会让"全新 install"和"沿着迁移升上来"产生 schema diff。
- **不做理由**：
  - 重写 0001 = 在历史链条上动初始 revision，所有现有部署回滚到 v1.2.3 之前会出问题。
  - 真要冻结历史，应该新开一个 `0001_freeze_v124` 的 baseline revision + 在 alembic.ini 加 `version_locations` 隔离，是一个独立工程。
- **替代缓解**：在 v1.2.4 加一个 **CI 守卫**：跑完所有迁移后 `alembic check`（或自写脚本对比 `Base.metadata` 和 inspector 拿到的 schema），如果出现 drift 立即红灯。这样能阻止漂移继续扩大。具体见 P0-3。

---

## 4. Phase 细则

> 每个 phase 给：覆盖问题号 / 改动文件（精确到行号或区域）/ 接口契约（如涉及）/ 测试计划 / 验收标准 / 工作量（S/M/L）/ 风险（低/中/高）。
>
> 实施顺序：**后端 schema → 后端 service → 后端 router → 前端 repository/client → 前端 UI → 测试**。

---

### Phase P0 — 基础设施加固

**覆盖**：#7（rate_limit proxy-headers）、#15（LLM scrypt 派生）、#16（OTP 节流 + 清理）、#21（email_sender 改 NotImplementedError 或 SMTP）、#24（settings 最小长度校验）、#29（DiagnosticLogger 文件轮转）、#30（deploy-hz.sh 参数化 ALTER ROLE）。

**工作量**：M｜**风险**：中（rate_limit/部署脚本动了任何一处都要灰度验证）

#### 改动清单

**P0-1 settings 强校验（#24 / #15）**

- 文件：`backend/app/main.py:12-26`、`backend/app/core/config.py:9-52`
- 新增 settings 字段（向后兼容，全部带默认值）：
  - `jwt_secret_key`：min length 32；`@field_validator` 当 `app_env == "production"` 时拒绝 < 32 或包含 `"change-me"`。
  - `llm_key_encryption_secret`：min length 32；同上规则。
  - `refresh_token_rotation_enabled: bool = True`（P2 用）。
  - `refresh_token_blacklist_ttl_days: int = 31`（P2 用，比 refresh TTL 多 1 天）。
  - `register_invite_token: str = ""`（P2 用，空即禁注册）。
  - `rate_limit_otp_per_email_per_hour: int = 5`（P0-4 用）。
- `validate_runtime_settings()` 在 prod 模式下追加上述硬校验，失败抛 `RuntimeError`，让 systemd 启不来即可。

**P0-2 LLM key 派生改 scrypt（#15）**

- 文件：`backend/app/services/agent_service.py:72-75`
- 函数 `_fernet()`：
  - 不再 `hashlib.sha256(secret)`，改 `hashlib.scrypt(secret, salt=fixed_salt, n=2**14, r=8, p=1, dklen=32)`。
  - `fixed_salt` 用 settings 里的新字段 `llm_key_encryption_salt: bytes` 派生（默认 `b"100j-llm-v1"`，prod 必须显式覆盖且 ≥ 16 bytes）；config.py 加同名校验。
- **兼容性**：派生函数变了，密文不通用。提供一次性数据迁移脚本 `backend/scripts/migrate_llm_keys_v124.py`：读出每行 → 用旧派生解密 → 用新派生重新加密写回，单步 idempotent。
- 在 README 部署章节加一条："运行 `python -m scripts.migrate_llm_keys_v124` 一次再升级 v1.2.4，否则现有 LLM key 会解不出"。

**P0-3 Alembic drift 守卫（替代 #17 缓解措施）**

- 新文件：`backend/scripts/check_alembic_drift.py`
- 行为：连内存 sqlite → `alembic upgrade head` → 用 `sqlalchemy.inspect` 读出实际 schema，对照 `Base.metadata` 找差异（表、列、索引），找到就 `sys.exit(1)`。
- 接入：`scripts/verify-release.sh` 末尾加 `python -m scripts.check_alembic_drift`。

**P0-4 rate_limit + OTP 节流（#7 / #16 / #20）**

- 文件：`backend/app/core/rate_limit.py`
  - 新增 `key_func`：优先取 `X-Forwarded-For` 第一段（且 `request.client.host == "127.0.0.1"` 才信任，否则退回 remote_address）。
  - 新增工具函数 `key_func_email(request, payload_attr="email")` 用于 OTP per-email 限流。
- 文件：`scripts/deploy-hz.sh:144`
  - `ExecStart` 改成：`uvicorn app.main:app --host 127.0.0.1 --port ${REMOTE_API_PORT} --proxy-headers --forwarded-allow-ips=127.0.0.1`
- 文件：`backend/app/services/email_otp_service.py:23-34`
  - `request_code` 内：在写新 row 前 `SELECT count(*) FROM email_otp_codes WHERE email=:e AND created_at > now()-interval '1 hour'`，超 `rate_limit_otp_per_email_per_hour` 抛 `AppError(429, "rate_limited", ...)`。
  - 新增 `cleanup_expired(db, older_than_days=7)`，删除 `expires_at < now() - 7d` 的行。
- 文件：`backend/app/api/v1/auth.py` 现有路由保持，仅给 `/me/seed-demo`（在 `backend/app/api/v1/spaces.py` 或 me 路由，由实际位置定）加 `@limiter.limit("3/hour")`（#20）。
- 新增定时任务：暂不引入 cron，改在 `request_code` 里 1% 概率触发 `cleanup_expired`（懒清理），文档备注未来 v1.2.5+ 上正经 cron。

**P0-5 email_sender 真实化（#21）**

- 文件：`backend/app/services/email_sender.py`
- 重写：
  - 若 `settings.email_otp_enabled` 且 `settings.smtp_host` 为空 → `get_email_sender()` 返回的 send 在 prod 直接 `raise NotImplementedError("SMTP not configured; refusing to print OTP to logs.")`，在 dev 仍 print（但带 `[DEV ONLY]` 前缀）。
  - 若 `smtp_host` 配置齐全 → 用 `smtplib.SMTP_SSL` 发送，subject = "100J 一次性登录验证码"，body 纯文本。
- config.py 新增字段：`smtp_host: str = ""`、`smtp_port: int = 465`、`smtp_user: str = ""`、`smtp_password: str = ""`、`smtp_from: str = ""`。

**P0-6 deploy-hz.sh 参数化（#30）**

- 文件：`scripts/deploy-hz.sh:111-115`
- 现状：`ALTER ROLE "100j" WITH LOGIN PASSWORD '${db_password}';` 是字符串拼接，密码含 `'` 会注入 / 失败。
- 改法：用 here-doc + `psql` 的 `\set` 变量：
  - 把 `db_password` 写入临时文件 `/tmp/100j-pw.sql`：`\set pw '...'` + `ALTER ROLE "100j" WITH LOGIN PASSWORD :'pw';`，然后 `psql -v ON_ERROR_STOP=1 -f /tmp/100j-pw.sql && rm /tmp/100j-pw.sql`。
  - 临时文件 `chmod 600`。
- 同时给 CREATE ROLE 分支同款处理。

**P0-7 DiagnosticLogger 文件轮转（#29）**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/Utilities/DiagnosticLogger.swift`
- 在 `append(_:)`（或当前等价的写文件方法）末尾增加：
  - 写完后 `FileManager.default.attributesOfItem(atPath: fileURL.path)` 拿 size。
  - 若 size > 1 MB → 移动当前文件到 `<name>.1.log`（已存在则覆盖），重新创建空 log。
- 暴露 `public static let rotationThresholdBytes: Int = 1_000_000`，方便测试。

#### 接口契约（新增 settings）

无 HTTP 接口变更。新增 settings 字段全部带默认值，向后兼容。

#### 测试计划

- `backend/tests/test_config.py` 增：
  - `test_jwt_secret_min_length_in_production`
  - `test_llm_secret_min_length_in_production`
  - `test_smtp_host_required_when_email_otp_enabled_and_prod`
- `backend/tests/test_auth_v11.py` 增：
  - `test_otp_per_email_throttle_blocks_6th_request_within_hour`
  - `test_otp_cleanup_removes_expired_rows`
- 新增 `backend/tests/test_rate_limit.py`：
  - `test_key_func_trusts_xff_only_from_loopback`
  - `test_key_func_falls_back_to_remote_address_when_xff_from_outside`
- 新增 `backend/tests/test_alembic_drift.py`：调用 `check_alembic_drift` 主函数，断言 exit code = 0。
- 新增 `frontend/apple/Tests/PersonalAffairsCoreTests/DiagnosticLoggerTests.swift`：写入直到超阈值 → 断言出现 `.1.log` 文件且当前文件 size = 0。

#### 验收标准

- `pytest backend/tests/ -q` 全绿。
- `scripts/verify-release.sh` 跑到底，含新加的 alembic drift check。
- 手动启动 backend：`AUTH_MODE=jwt APP_ENV=production JWT_SECRET_KEY=short python -m uvicorn app.main:app` 应启动失败并打印明确错误。

---

### Phase P1 — Device session 刷新链路修复（致命核心）

**覆盖**：#1（device-refresh 路径错乱）、#6（device-logout 未鉴权）、#8（expireCloudSession 不清 DeviceSessionStore）、#12（401 闪烁）、#25（DeviceSession 复用旧 row 时 revoked_at 残留）。

**工作量**：L｜**风险**：高（动认证主路径；回归测试要把所有"登录后刷新场景"覆盖到）

#### 改动清单

**P1-1 后端：device-logout 加鉴权 + revoked_at 修正（#6 / #25）**

- 文件：`backend/app/api/v1/auth.py:149-152`
- 改 endpoint：
  - 接收 `DeviceLogoutRequest`（新增字段 `refresh_token: Optional[str]`，已存在则保留）。
  - 鉴权策略（任一即可，按顺序匹配）：
    1. 请求带 `Authorization: Bearer <access_jwt>` 且 jwt 校验通过 → 取 `sub` 作为 user_id，要求 `device_id` 对应的 session 属于该 user，否则 404。
    2. 请求 body 带 `refresh_token` → 调 `device_session_service.verify(db, device_id, presented_refresh_token)`（新增函数，**不 rotate**，仅校验哈希），成功才 revoke。
  - 都不满足 → `AppError(401, "unauthorized", "Device logout requires auth.")`。
- 文件：`backend/app/services/device_session_service.py`
  - 新增 `verify(db, *, device_id, presented_refresh_token) -> DeviceSession`：复用 `rotate` 的校验段，不更新 token。
  - 修 `issue(...)` 中 "existing row 复用" 分支（行 76-84）：先断言 `existing.revoked_at is None`，若已 revoke 则**视作不存在**新建一行，避免 #25 描述的复活漏洞。
- 文件：`backend/app/schemas/auth.py`
  - `DeviceLogoutRequest` 增 `refresh_token: Optional[str] = None`。

**P1-2 前端 APIClient：401 → silent resume（#1 / #12）**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/API/APIClient.swift:118-127, 175-194`
- 关键改动：APIClient 需要"感知 device-session 模式"。新增初始化参数：
  - `private let deviceSession: DeviceSessionStore?`
  - `public init(..., deviceSession: DeviceSessionStore? = .shared)`
- `refreshTokensIfPossible()` 行 175-194 重写：
  - 若 `deviceSession?.hasActiveSession == true` 且 `deviceSession.refreshToken != nil`：
    - POST `/auth/device-refresh`，body = `{device_id, refresh_token}`。
    - 成功 → `tokenStore.save(access, refresh)` + `deviceSession.saveRefreshToken(refresh)` + `deviceSession.recordIssued(...)` → return true。
    - 失败 → 走 fallback 到旧 `/auth/refresh` 路径（保 JWT-only 模式）；都失败才 `clear()` + return false。
  - 现状的 JWT-only 走旧逻辑保留。
- 401 冷却（#12）：APIClient 维护 `lastUnauthorizedHandledAt: Date?`，同一 `path` 在 5 秒内的二次 401 不再触发 `expireCloudSession` 链路（仅 throw `APIClientError.unauthorized`，让上层静默）。

**P1-3 前端 AppModel：401 自愈 + 清理 DeviceSessionStore（#8）**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/App/AppModel.swift:895-929, 998-1015`
- `run(_:)` 行 895-906：捕到 `APIClientError.unauthorized` 时：
  1. 若 `hasDeviceSession` → `try? await authRepository.silentResume()` → 成功则**重试一次** `operation()`。
  2. 失败才走 `expireCloudSession()`。
- `expireCloudSession()` 行 908-929：在 `try? api.tokenStore.clear()` 后追加 `deviceSession.clearAll()`，否则 RootView 看到 `hasDeviceSession == true` 一直 stuck 在 `ResumingPlaceholder`。
- 额外保险：`RootView` 的 `ResumingPlaceholder` 出现时主动触发 `model.bootstrapIfPossible()`，5 秒未恢复则 `model.expireCloudSession()`。文件：`frontend/apple/Sources/PersonalAffairsApp/App/RootView.swift:49-63` 增 `.task { ... }`。

**P1-4 前端 AuthRepository.silentResume 健壮化（#1 联动）**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/Repositories/AuthRepository.swift:92-106`
- `silentResume()` 抛 `APIClientError.unauthorized` 之前，先 `deviceSession.clearAll()`，让上游 RootView 跳回 SetupScreen，而不是无限 placeholder。

#### 接口契约（变更）

**修改：`POST /api/v1/auth/device-logout`**

| 项 | v1.2.3 | v1.2.4 |
| --- | --- | --- |
| 鉴权 | 无 | 二选一：`Authorization: Bearer <jwt>` 或 body 带 `refresh_token` |
| Request body | `{device_id: string}` | `{device_id: string, refresh_token?: string}` |
| 成功 | 204 | 204 |
| 失败码 | — | `401 unauthorized` `Device logout requires auth.` |
| | | `404 not_found` `Device session not found.` |

**保持不变**：`POST /api/v1/auth/device-refresh`（路径、参数、响应都不动）。

#### 测试计划

- 后端 `backend/tests/test_auth_v11.py` 增：
  - `test_device_logout_requires_auth_returns_401_when_no_token`
  - `test_device_logout_with_access_jwt_succeeds`
  - `test_device_logout_with_refresh_token_succeeds`
  - `test_device_logout_with_wrong_refresh_token_returns_401`
  - `test_issue_after_revoke_creates_fresh_row_or_resets_cleanly`（#25）
- 前端 `frontend/apple/Tests/PersonalAffairsCoreTests/ViewModelTests.swift` 增：
  - `test_apiClient_uses_deviceRefresh_when_device_session_active`（mock URLProtocol）
  - `test_apiClient_falls_back_to_jwt_refresh_when_no_device_session`
  - `test_unauthorized_cooldown_blocks_double_session_expire_within_5s`
- 前端新增 `AppModelAuthFlowTests.swift`：
  - `test_run_recovers_from_401_via_silent_resume`
  - `test_run_calls_expireCloudSession_when_silent_resume_fails`
  - `test_expireCloudSession_clears_device_session_store`

#### 验收标准

- 模拟 30min access token 过期：APIClient 自动调 `/auth/device-refresh`，请求继续；用户**无感知**。
- 模拟 device session 被服务端撤销：401 → silent resume 失败 → 自动跳回 SetupScreen（不卡 ResumingPlaceholder）。
- `tests/test_auth_v11.py` + 上述前端测试全绿。
- 手测：macOS 客户端登录后用 `psql` 把 `device_sessions.expires_at` 改成 `now() - 1 day` → 下次请求自动跳出登录页（旧版会卡 placeholder）。

---

### Phase P2 — 注册/登录入口收口

**覆盖**：#5（/auth/register 公开）、#18（Apple JWKS 拉取无容错）、#19（/auth/refresh 无 rotation/黑名单）、#20（/me/seed-demo 限流，已含在 P0）、#16（OTP per-email 节流，已含在 P0）。

**工作量**：M｜**风险**：中（涉及 jti 黑名单新表）

#### 改动清单

**P2-1 /auth/register 收口（#5）**

- 文件：`backend/app/api/v1/auth.py:55-64`
- 改为：
  - 若 `settings.app_env == "production"` 且 `settings.register_invite_token == ""` → 直接 `raise AppError(404, "not_found", "Registration disabled.")`。
  - 否则：要求 request header `X-Invite-Token` == `settings.register_invite_token` 才放行；不匹配 → 401。
  - 加 `@limiter.limit("3/hour")`。
- `RegisterRequest` 不变。

**P2-2 Apple JWKS 容错（#18）**

- 文件：`backend/app/services/apple_auth_service.py:19-31`
- `_jwks()`：
  - try 抓 → 失败时 if `_jwks_cache["keys"]` 存在则把 `expires_at` 延长 1h 复用旧缓存 + 写 `logger.warning("apple_jwks_unreachable, reusing stale")`。
  - 全无缓存（首启 + apple 挂）才抛 `AppError(503, "upstream_unavailable", "Apple JWKS unreachable.")`。
- 全模块顶部加 `import logging; logger = logging.getLogger(__name__)`。

**P2-3 refresh rotation + jti 黑名单（#19）**

- 新增 alembic 迁移 `backend/alembic/versions/0006_refresh_token_jti.py`：
  - 新表 `refresh_token_jti`：
    - `jti: str`（pk，UUID）
    - `user_id: str`（fk users.id，indexed）
    - `issued_at: datetime`
    - `expires_at: datetime`
    - `revoked_at: Optional[datetime]`
  - 创建复合索引 `(user_id, expires_at)` 用于清理。
- 文件：`backend/app/models/__init__.py` 或新文件 `backend/app/models/auth.py`：声明 `RefreshTokenJTI` 模型。
- 文件：`backend/app/core/security.py`：
  - `create_refresh_token(user_id, jti=None)` 在 payload 加 `jti` claim（UUID4 默认值）。
  - 暴露 `decode_token` 已能返回 jti，无需改。
- 文件：`backend/app/services/auth_service.py`：
  - `issue_tokens(user)` 在创建 refresh 时把 jti 落库 `RefreshTokenJTI(jti=..., user_id=user.id, expires_at=now+30d)`。
- 文件：`backend/app/api/v1/auth.py:123-131`
  - `refresh` 路由改：
    1. `decode_token(refresh_token, expected_type="refresh")` → 拿 `sub`、`jti`。
    2. 查 `RefreshTokenJTI`：不存在 / `revoked_at != None` / `expires_at <= now()` → `AppError(401, "unauthorized", "Refresh token revoked.")`。
    3. **rotation**：把旧 jti `revoked_at = now()`；生成新 jti 入库；签发新 access + refresh 返回。
  - 加 `@limiter.limit("60/minute")`（与 device-refresh 对齐）。
- 启动定时清理：在 `auth_service.cleanup_expired_jti(db)` 中 `DELETE FROM refresh_token_jti WHERE expires_at < now() - 1 day`，在 P0-4 的"懒清理"思路下，给 `issue_tokens` 也加 1% 概率触发。

**P2-4 客户端兼容**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/Repositories/AuthRepository.swift`
- 现状 `persist()` 已经能保存返回的新 refresh token；rotation 后只要客户端正确保存，行为不变。
- 验证：`AuthRepository.silentResume` 单测里加一条 "连续刷新 2 次都成功且 refreshToken 变化"。

#### 接口契约（变更）

**修改：`POST /api/v1/auth/refresh`**

| 项 | v1.2.3 | v1.2.4 |
| --- | --- | --- |
| 行为 | 仅校验 JWT 签名，每次发同样 refresh | 校验 jti 未撤销 + rotation 发新 refresh |
| Request body | `{refresh_token: string}` | 不变 |
| Response | `{access_token, refresh_token, token_type, expires_at?}` | 不变（refresh_token 必然变化） |
| 新错误码 | — | `401 unauthorized` `Refresh token revoked.` |
| | | `429 rate_limited` |

**修改：`POST /api/v1/auth/register`**

| 项 | v1.2.3 | v1.2.4 |
| --- | --- | --- |
| 可用性 | 公开（任何人可注册） | prod 默认 404；dev 或带 `X-Invite-Token` 才放行 |
| 新错误码 | — | `404 not_found` `Registration disabled.` |
| | | `401 unauthorized` `Invalid invite token.` |
| | | `429 rate_limited` |

#### Alembic 迁移

| Revision | 文件 | 操作 |
| --- | --- | --- |
| `0006_refresh_token_jti` | `backend/alembic/versions/0006_refresh_token_jti.py` | `op.create_table("refresh_token_jti", ...)` + 复合索引；downgrade `op.drop_table(...)` |

**回滚要求**：迁移必须 `downgrade()` 完全反转。CI 跑 `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` 校验。

#### 测试计划

- 后端 `tests/test_auth_v11.py` 增：
  - `test_refresh_rotates_jti_and_invalidates_old_token`
  - `test_refresh_revoked_jti_returns_401`
  - `test_refresh_expired_jti_returns_401`
  - `test_register_in_prod_without_invite_returns_404`
  - `test_register_in_prod_with_invite_succeeds`
- 后端 `tests/test_auth_spaces.py` / 新文件 `test_apple_auth.py`（建议拆出来）增：
  - `test_apple_sign_in_falls_back_to_stale_jwks_when_remote_unreachable`
- 前端测试新增：
  - `test_silentResume_handles_rotation_and_saves_new_refresh`

#### 验收标准

- `pytest -q -k "refresh or register or apple"` 全绿。
- `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无报错。
- prod 配置（`APP_ENV=production`、`REGISTER_INVITE_TOKEN=`）下，`curl POST /api/v1/auth/register` 返回 404。

---

### Phase P3 — Apple Sign-In 安全 + 死代码取舍

**覆盖**：#2（email_hint 信任漏洞，致命）、#11（KeychainAccessGroup dead intent）、#13（Apple Sign-In 前端死代码 + entitlement 缺失）。

**工作量**：M｜**风险**：中（涉及 Xcode 项目配置）

#### 决策

> 关键产品决策：**v1.2.4 暂不上 Apple Sign-In**，因为 entitlement、AppleID 配置、隐私 policy 都没就绪。本 phase 选择 **"全部下线 / 标 unavailable"** 路线。如果未来要重启，独立做一个 v1.3.0 feature。

#### 改动清单

**P3-1 后端：Apple email_hint 收紧（#2）**

- 文件：`backend/app/services/apple_auth_service.py:73-83`
- 改动逻辑：
  - 现状：`email = (claims.get("email") or email_hint or "").strip().lower() or None`，且 80 行 `if user is None and email: user = db.scalar(select(User).where(User.email == email...))` 直接拿 hint 匹配既有 user。
  - 改成：
    - `apple_email = (claims.get("email") or "").strip().lower() or None`
    - 仅 `apple_email`（来自 id_token claim）参与"按邮箱匹配既有 user"。
    - `email_hint` 仅在**新建 user 且 claim 没给 email**时用作初始 display/email 候选。
    - 若 `apple_email` 与 `email_hint` 都没有 → 新 user 用 `f"apple-{apple_user_id[:8]}@private.local"` 占位，避免 NOT NULL 失败。
- 单独函数 `_match_existing_user(db, apple_user_id, apple_email) -> Optional[User]` 提取出来便于测试。

**P3-2 后端：Apple endpoint feature flag（与 P3-3 联动）**

- 文件：`backend/app/api/v1/auth.py:87-103`
- 加 `apple_sign_in_enabled: bool = False`（settings 新字段，默认关）。endpoint 入口若 `False` → `AppError(404, "not_found", "Apple Sign-In disabled.")`。
- 不删 endpoint 代码（保留后续 v1.3.0 复用），只是默认 disabled。

**P3-3 前端：删 Apple Sign-In 死代码（#13）**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/DesignSystem/AppleSignInButton.swift`
  - 标记 `@available(*, unavailable, message: "Apple Sign-In 推迟到 v1.3.0")`，方法 body 改成 `EmptyView()`。
  - 或直接删除文件 + 在 git commit message 注明 "v1.3.0 重新引入"。
  - **推荐**：删文件，干净。
- 文件：`frontend/apple/Sources/PersonalAffairsApp/App/AppModel.swift:323-353`
  - 删 `signInWithApple(...)` 方法 + 相关 `import AuthenticationServices`。
- 文件：`frontend/apple/Sources/PersonalAffairsApp/Features/Auth/SetupScreen.swift`（如有 Apple 按钮入口）：
  - 删按钮 UI；保留 email + access code 两条入口。
- 文件：`frontend/apple/Sources/PersonalAffairsCore/Repositories/AuthRepository.swift:51-68`
  - `signInWithApple(...)` 方法保留（编译器需要保持 public API，且后端 endpoint 还在），加 `@available(*, deprecated, message: "v1.2.4: feature gated off")`。

**P3-4 前端：KeychainAccessGroup 取舍（#11）**

- 决策：**删整段**。理由：当前 entitlements 没声明 keychain-access-groups，调用 `configure()` 是空操作，留着误导。
- 文件：`frontend/apple/Sources/PersonalAffairsCore/API/TokenStore.swift:113-115, 129-131, 154-156, 161-171`、`frontend/apple/Sources/PersonalAffairsCore/API/DeviceSessionStore.swift:143-145, 159-161, 186-188`
  - 删除所有 `if let group = KeychainAccessGroup.identifier { query[kSecAttrAccessGroup...] = group }` 分支。
  - 删除 `public enum KeychainAccessGroup { ... }`。
- 文件：`frontend/apple/Sources/PersonalAffairsApp/App/PersonalAffairsApp.swift:8-15`
  - 删除任何 `KeychainAccessGroup.configure(...)` 调用（如有）。
- 文件：`frontend/apple/Sources/PersonalAffairsApp/Resources/PersonalAffairsApp.macOS.entitlements`、`PersonalAffairsApp.iOS.entitlements`
  - 不动（本来就没声明）。

#### 接口契约（变更）

**修改：`POST /api/v1/auth/apple`**

| 项 | v1.2.3 | v1.2.4 |
| --- | --- | --- |
| 可用性 | 默认开 | 默认 disabled（404）；需 `APPLE_SIGN_IN_ENABLED=true` 才开 |
| Request body | 不变 | 不变 |
| Response | 不变 | 不变 |
| 新错误码 | — | `404 not_found` `Apple Sign-In disabled.` |
| **关键行为** | `email_hint` 可用于匹配既有 user（漏洞） | `email_hint` 仅用于新建 user 兜底 |

#### 测试计划

- 后端新文件 `backend/tests/test_apple_auth.py`（如还没有）：
  - `test_apple_email_hint_does_not_match_existing_user_when_claim_missing_email`
  - `test_apple_email_claim_matches_existing_user`
  - `test_apple_new_user_uses_email_claim_when_present`
  - `test_apple_new_user_uses_hint_when_claim_email_missing`
  - `test_apple_endpoint_returns_404_when_disabled`
- 前端：删除涉及 Apple Sign-In 的现有 test case（或 `XCTSkip(...)` 加注释）。

#### 验收标准

- `pytest -q tests/test_apple_auth.py` 全绿。
- `grep -rn "KeychainAccessGroup\|AppleSignInButton\|signInWithApple" frontend/apple/Sources` 结果只剩 `AuthRepository.signInWithApple`（deprecated 标记）一处。
- macOS / iOS 双 target xcodebuild 编译通过。
- 手测：SetupScreen 上没有"用 Apple 登录"按钮。

---

### Phase P4 — Calendar 全天/有时字段一致性

**覆盖**：#4（all_day 切换后 422 静默，致命）、#22（end >= start 校验）、#23（Note.linked_task_id PATCH 无校验）。

**工作量**：S｜**风险**：低

#### 改动清单

**P4-1 后端 calendar all_day 自动清字段（#4）**

- 文件：`backend/app/services/calendar_service.py:108-130`
- `update_calendar_item` 在合并 `merged` 之后、`validate_calendar_fields(merged)` 之前，加规整：
  - 若 `merged["all_day"] is True`：强制 `merged["start_at"] = None`、`merged["end_at"] = None`。
  - 若 `merged["all_day"] is False`：强制 `merged["start_date"] = None`、`merged["end_date"] = None`。
  - 同步把这两条规整写回 `data`，确保后续 `for field, value in data.items(): setattr(item, field, value)` 实际持久化。
- 同理在 `create_calendar_item`（行 77-97）里加同款规整，避免 create 路径走偏。

**P4-2 后端 end >= start 校验（#22）**

- 文件：`backend/app/services/validation_service.py:155-167`
- `validate_calendar_fields(data)` 末尾追加：
  - 若 `all_day`：当 `end_date` 非空 → `assert end_date >= start_date` else `raise validation_error("end_date must be >= start_date.")`。
  - 若 `not all_day`：当 `end_at` 非空 → `assert end_at >= start_at` else `raise validation_error("end_at must be >= start_at.")`。

**P4-3 后端 Note.linked_task_id 校验（#23）**

- 文件：`backend/app/services/note_service.py`
- `update_note` 路径在合并 `merged` 后，若 `linked_task_id` 字段被设置且非空：
  - `task = get_owned_task(db, user_id, linked_task_id)`（404 自动抛）。
  - 校验 `task.user_id == user_id`（get_owned_task 已含）。
  - 可选：校验 task.space.type == "personal"（与 note 同 space type）以与 v1.2.x 业务一致。

**P4-4 前端 calendar 422 兜底（与 #4 联动 / 防御性）**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/ViewState/CalendarViewState.swift:104-117`
- 修复后**后端兜底是主线**；前端不需要硬改 encoder。但为防御未来再回归，加一条：
  - `updateRequest(...)` 显式断言：若 `allDay == true` → `startAt = nil`（已是）；并在 debug build 加 `assert(startDate != nil || !allDay)`。

#### 接口契约

无新增 endpoint。`PATCH /api/v1/calendar-items/{id}` 与 `PATCH /api/v1/notes/{id}` 行为收紧（更严格的 422）。

#### 测试计划

- 后端 `tests/test_business_rules.py` 增：
  - `test_calendar_update_switches_from_timed_to_all_day_clears_start_at`
  - `test_calendar_update_switches_from_all_day_to_timed_clears_start_date`
  - `test_calendar_update_rejects_end_before_start`
  - `test_note_update_rejects_linked_task_from_other_user`（构造另一 user 的 task_id，期望 404）
- 前端 `ViewModelTests.swift` 增：
  - `test_calendarDraft_updateRequest_all_day_true_omits_startAt`

#### 验收标准

- 手测：iOS 客户端编辑 timed 事件 → 切换到 all-day → 保存 → 后端持久化为纯 date，前端列表显示无错位。
- 上述测试全绿。

---

### Phase P5 — Agent 并发 + 加密 + UI 补口

**覆盖**：#10（confirm_command 无原子锁）、#15（已在 P0-2 处理）、#32（AgentScreen 不展示 pendingConfirmation 入口）、#34（JSONValue.description object 输出非确定）。

**工作量**：S–M｜**风险**：低

#### 改动清单

**P5-1 confirm_command 加原子锁（#10）**

- 文件：`backend/app/services/agent_service.py:204-227`
- 改 `confirm_command(db, user_id, confirmation_token)`：
  - 用 `DELETE FROM agent_pending_confirmations WHERE token=:t AND user_id=:u RETURNING command, arguments` 一句完成"找+删"。
  - 若 affected rows == 0 → `AppError(404, ..., "Confirmation token not found or already used.")`。
  - 时间过期判定仍保留（用 RETURNING 拿到 expires_at 后判断）。
- 实现细节：SQLAlchemy 2.x 用 `db.execute(delete(AgentPendingConfirmation).where(...).returning(...))`，依赖 PostgreSQL 的 DELETE...RETURNING 语义。
- 单测必须在 sqlite-in-memory + postgres-via-fixture 都覆盖；sqlite 不支持 RETURNING 时退化为 `SELECT ... FOR UPDATE`（用 `with_for_update()`）+ `delete()`。

**P5-2 AgentScreen 展示 pendingConfirmation 入口（#32）**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/Features/Screens/AgentScreen.swift`
- 现状：pendingConfirmation 仅靠 sheet 弹出，sheet 被 dismiss 后无入口，用户要等 15min 过期。
- 改：在 AgentScreen 顶部加一行 banner（仅当 `model.agentReview.pendingConfirmation != nil`）：
  - 文案 "有一条待你确认的操作：{command}"
  - 右侧 button "查看" → 触发 `model.agentReview.showConfirmationSheet = true`（或等价 binding）。
- 文件：`frontend/apple/Sources/PersonalAffairsCore/ViewState/AgentReviewState.swift` 或 `AgentReviewSession.swift`
  - 暴露 `var pendingConfirmation: PendingConfirmation?` 让 SwiftUI 监听（如已存在则只需暴露 public getter）。

**P5-3 JSONValue.description 排序（#34）**

- 文件：找当前 `JSONValue` 类型所在文件（推测 `frontend/apple/Sources/PersonalAffairsCore/Domain/...` 或 `Utilities/`）。先 grep 定位。
- 行为：`.object(let dict)` 分支的 description 输出按 `dict.keys.sorted()` 顺序拼装。
- 用途：日志可复现 / 测试 snapshot 稳定。

#### 接口契约

`POST /api/v1/agent/confirm` 行为收紧（同一 token 并发两次只有一次成功，第二次拿 404）。响应结构不变。

#### 测试计划

- 后端 `tests/test_agent.py` 增：
  - `test_confirm_command_atomic_under_concurrency`：用线程池跑两次 confirm 同一 token，断言成功次数 == 1，另一次 404。
- 前端 `ViewModelTests.swift` 增：
  - `test_agentScreen_shows_banner_when_pending_confirmation_present`
  - `test_jsonValue_object_description_is_sorted`

#### 验收标准

- 并发测试稳定通过 100 次（CI 加 `--count=100` 跑一次）。
- 手测：在 macOS 上让 agent 提一个 risky update → 关掉 sheet → 主屏看到 banner → 点 banner 重新弹 sheet → 确认成功。

---

### Phase P6 — 客户端鲁棒性 + Widget

**覆盖**：#3（Widget 永远空数据，致命）、#9（logout 不清 MutationQueue）、#26（MutationQueue 错误归类）、#27（TodayScreen 全量刷未节流）、#28（LocalNotificationCenter 重复 requestAuthorization）、#31（MutationQueue 重放无退避）、#33（Note.body 16001 边界未覆盖）。

**工作量**：M｜**风险**：中（Widget 跨 process + App Group 是签名相关，CI 不一定能完整验证）

#### 改动清单

**P6-1 Widget App Group（#3，致命）**

- 文件：`frontend/apple/Sources/OneHundredJWidgets/OneHundredJWidgets.swift`
- `OneHundredJWidgetsBundle` 加 `init()`：
  ```
  init() {
      WidgetSnapshotStore.useAppGroup("group.top.linotsai.app.PersonalAffairs")
  }
  ```
  注意：WidgetBundle 是 struct，加 init 即可，SwiftUI runtime 会调用。
- 验证宿主端：`frontend/apple/Sources/PersonalAffairsApp/App/PersonalAffairsApp.swift:8-15` 当前仅 iOS 调 `useAppGroup`。**保持现状**（macOS 仍 per-app，避免 ad-hoc TCC 弹窗），因为 macOS widget extension 在 ad-hoc 签名下也读不到 group container，这是已知 ad-hoc 限制；user iOS 上是主目标场景。
- 给 macOS widget 加运行时 fallback：若 `useAppGroup` 后 `WidgetSnapshotStore.load()` 仍 empty 且当前 platform 是 macOS → 回退读 `UserDefaults.standard`（host macOS 写的位置）。
  - 在 `WidgetSnapshotStore.load()` 内：`defaults.data(forKey:) ?? UserDefaults.standard.data(forKey:)` 兜底。

**P6-2 entitlement / Xcode 项目检查**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/Resources/PersonalAffairsApp.iOS.entitlements`
- 必须包含：
  ```
  <key>com.apple.security.application-groups</key>
  <array>
      <string>group.top.linotsai.app.PersonalAffairs</string>
  </array>
  ```
- Widget extension 的 entitlements 文件（若不存在则需要在 Xcode 新建 `OneHundredJWidgets.entitlements`，与 iOS App Group 同款）。
- 文件：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj` 确认 widget target 的 `CODE_SIGN_ENTITLEMENTS` 指向新文件。
- **若 Xcode 项目改动较大**：用 Xcode GUI 操作然后 commit `project.pbxproj`，不要手改 pbxproj（容易破坏 build phase）。这一步在 builder agent 执行时建议人工介入。

**P6-3 MutationQueue 与 logout（#9 / #26 / #31）**

- 文件：`frontend/apple/Sources/PersonalAffairsCore/Utilities/MutationQueue.swift`
- 现状：mutation 不带 user_id；replay 错误归 dropPermanent；replay 串行无退避。
- 改：
  - `PendingMutation` 结构增 `userId: String`。enqueue 时由 AppModel 注入 `currentUser?.id ?? "local-user"`。
  - `replay(using api: APIClient, currentUserId: String)`：循环开头跳过 `mutation.userId != currentUserId` 的 row（这些是上个 user 的，做归档：移到 `MutationQueue.orphanedMutations.json`，**不删**，留诊断）。
  - 网络错误（`URLError.notConnectedToInternet` / timeout）→ 不计入 dropPermanent，回写 `attempts++`；当 `attempts >= 5` 才 dropPermanent。
  - 重试间隔：第 N 次 retry 间隔 `min(2^N seconds, 30s)`。
- 文件：`frontend/apple/Sources/PersonalAffairsApp/App/AppModel.swift:409-427, 998-1015`
  - `logout()` 内：`await mutationQueue.archiveAllForCurrentUserAndClear()`（新方法：把当前 user 的 pending 移到 archived，不发送）。
  - `replayPendingMutations()` 传 `currentUserId: currentUser?.id ?? "local-user"`。

**P6-4 TodayScreen 节流（#27）**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/Features/Screens/TodayScreen.swift`
- 现状：`.task { await model.refreshAll() }` 每次 view appear 全量刷。
- 改：AppModel 加 `private var lastRefreshAllAt: Date?`；`refreshAll()` 开头若 `Date().timeIntervalSince(lastRefreshAllAt ?? .distantPast) < 30` → 直接 return（仍触发 `refreshDerivedViewModels()` 让 UI 走一遍 derive）。
- 手动刷新（菜单栏 "刷新" 命令）走 `refreshAll(force: true)` 绕过节流。

**P6-5 LocalNotificationCenter 查 settings 再 request（#28）**

- 文件：`frontend/apple/Sources/PersonalAffairsApp/App/LocalNotificationCenter.swift`
- `sync(items:)` 开头：
  ```
  let settings = await UNUserNotificationCenter.current().notificationSettings()
  switch settings.authorizationStatus {
  case .notDetermined:
      _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
  case .denied:
      return  // 不强求
  default:
      break
  }
  ```

**P6-6 Note.body 16001 边界测试（#33）**

- 文件：`backend/tests/test_business_rules.py`
- 增：
  - `test_note_body_at_16000_chars_succeeds`
  - `test_note_body_at_16001_chars_rejected`（期望 422）

#### 接口契约

无变更。

#### 测试计划

- 后端：见 P6-6。
- 前端新增 `MutationQueueTests.swift`：
  - `test_replay_skips_other_user_mutations_and_archives_them`
  - `test_replay_uses_exponential_backoff_up_to_30s`
  - `test_replay_does_not_drop_permanent_on_network_error_within_5_attempts`
  - `test_logout_archives_queue_for_current_user`
- 前端新增 `TodayScreenThrottleTests.swift`（或在已有 AppModel test 加）：
  - `test_refreshAll_within_30s_is_skipped_unless_forced`
- Widget 端测试受签名限制无法 CI 自动化，加**手测**清单。

#### 验收标准

- iOS 设备装上 v1.2.4：Widget 在添加后 5 分钟内显示真实 Top 3 + Agenda。
- macOS 客户端 logout user A → login user B：B 的离线写入不会被 A 的 queue 污染。
- 关掉网络做 3 次离线 mutation → 开网 → 全部成功重放（无 dropPermanent）。

---

### Phase P7 — 发布工程

**覆盖**：#30 已在 P0；本 phase 处理版本号 + 文档 + CI/部署脚本最终检查 + 回滚预案。

**工作量**：S｜**风险**：中（动 Xcode 项目版本号 + 部署脚本，发版必经）

#### 改动清单

**P7-1 版本号**

- 文件：`frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`
- 双 target（App + Widget）行 321/335/353/367 等所有出现处：
  - `MARKETING_VERSION = 1.2.3;` → `1.2.4`
  - `CURRENT_PROJECT_VERSION = 1.125;` → `1.126`
- 文件：`backend/pyproject.toml`：`version = "1.2.4"`。
- 文件：`backend/app/main.py:32`：`version="0.1.0"` 改成 `version="1.2.4"`（顺便修正 OpenAPI snapshot，详见 P7-2）。

**P7-2 OpenAPI snapshot 刷新**

- 文件：`backend/tests/openapi_snapshot.json`
- 在所有 schema/router 改动合入后，运行 `python -m backend.scripts.dump_openapi`（若不存在则按 `tests/test_openapi.py` 的 fixture 反推命令）刷新 snapshot。
- 提交时人工 diff 检查：仅 v1.2.4 预期变化（device-logout 加可选 refresh_token、refresh 加错误码、register 加错误码、apple 加 404）。

**P7-3 deployment.md 增 v1.2.4 段落**

- 文件：`deployment.md`
- 追加：
  - "v1.2.4 升级注意事项"段落，列：
    1. 先跑 `python -m scripts.migrate_llm_keys_v124`（P0-2 派生改了，必跑）。
    2. 部署前确认 `.env` 含 `REGISTER_INVITE_TOKEN=`、`SMTP_HOST=...`（OTP 启用时）、`APPLE_SIGN_IN_ENABLED=false`。
    3. `alembic upgrade head` 会执行 0006_refresh_token_jti。
    4. systemd 单元 `100j-api.service` 的 `ExecStart` 多了 `--proxy-headers --forwarded-allow-ips=127.0.0.1`，`scripts/deploy-hz.sh` 已更新；旧机器需要 `systemctl daemon-reload && systemctl restart 100j-api`。

**P7-4 prod-check.sh 增项**

- 文件：`scripts/prod-check.sh`
- 增 curl 检查：
  - `curl -s -o /dev/null -w "%{http_code}" -X POST $API_BASE/auth/register -H 'Content-Type: application/json' -d '{}'` 期望 404。
  - `curl -s -o /dev/null -w "%{http_code}" -X POST $API_BASE/auth/device-logout -H 'Content-Type: application/json' -d '{"device_id":"x"}'` 期望 401。
  - 验证 `/health` 真实通过反代而非直连（带 `X-Forwarded-For: 8.8.8.8` 触发 rate-limit 后从 8.8.8.8 计费）。

**P7-5 CI 强化**

- `scripts/verify-release.sh`（如已有则补、没有则新建）：
  - `pytest -q backend/tests`
  - `python -m scripts.check_alembic_drift`
  - `cd frontend/apple && xcodebuild -scheme PersonalAffairsApp -destination 'platform=macOS' -quiet test`
  - `cd frontend/apple && xcodebuild -scheme PersonalAffairsApp -destination 'generic/platform=iOS Simulator' -quiet build`

#### 测试计划

无新增测试，仅确认上述脚本 exit 0。

#### 验收标准

- `git tag v1.2.4` 前：`scripts/verify-release.sh` 一键全绿。
- `scripts/prod-check.sh` 在 HZ 灰度环境无报错。

---

## 5. 跨 phase 公共改动汇总

便于 builder 检查"是不是漏改"：

| 主题 | 涉及文件 | 涉及 phase |
| --- | --- | --- |
| `Settings` 新增字段 | `backend/app/core/config.py` | P0, P2, P3 |
| `validate_runtime_settings` 强校验 | `backend/app/main.py` | P0 |
| `rate_limit.key_func` + slowapi 装饰 | `backend/app/core/rate_limit.py`、`backend/app/api/v1/auth.py`、`backend/app/api/v1/spaces.py`(seed-demo) | P0, P2 |
| Alembic 新版本 0006 | `backend/alembic/versions/0006_refresh_token_jti.py`、`backend/app/models/...` | P2 |
| `DeviceLogoutRequest` schema 改动 | `backend/app/schemas/auth.py`、客户端 `Requests.swift` | P1 |
| Xcode 项目版本号 / entitlements | `frontend/apple/PersonalAffairsApp.xcodeproj/project.pbxproj`、`Resources/*.entitlements` | P6, P7 |
| OpenAPI snapshot | `backend/tests/openapi_snapshot.json` | P7（最后） |
| `deployment.md` | `deployment.md` | P7 |

---

## 6. 已决定延后的项（再次明确）

| 编号 | 描述 | 决策 | 在 v1.2.5 之前的缓解 |
| --- | --- | --- | --- |
| #14 | 分页改 keyset | **延后** | `paginate` 增"翻页拿到完整集合"单测；在 README 标 Known Limitation |
| #17 | Alembic 0001 改 `op.create_table` | **延后** | P0-3 上 drift CI 守卫，阻止情况恶化 |

其余 32 条全部落 phase。

---

## 7. 发布检查清单

### 7.1 自动化（CI 必过）

- [ ] `pytest -q backend/tests` 全绿
- [ ] `python -m scripts.check_alembic_drift` exit 0
- [ ] `alembic upgrade head && alembic downgrade base && alembic upgrade head` 三连无错
- [ ] macOS xcodebuild test 绿
- [ ] iOS xcodebuild build 绿（Simulator）
- [ ] `scripts/verify-release.sh` exit 0
- [ ] `backend/tests/openapi_snapshot.json` 已 review，diff 与 v1.2.4 预期吻合

### 7.2 灰度（HZ 云）

- [ ] `scripts/deploy-hz.sh` 部署到灰度机
- [ ] `scripts/prod-check.sh` 全绿
- [ ] `journalctl -u 100j-api -n 200` 无 ERROR
- [ ] `psql -c "SELECT count(*) FROM refresh_token_jti"` 数字随刷新单调增长

### 7.3 手测（owner 亲测）

- [ ] iOS：登录 → 主屏点 Home → 添加 Widget → Top 3/Agenda 显示真实数据（**致命 #3 验收**）
- [ ] macOS：登录后挂置 30min（或 SQL 把 access_token 临时调短）→ 操作能继续，不弹"已失效"（**致命 #1 验收**）
- [ ] macOS：编辑 Calendar item，timed → all-day 切换 → 保存 → 列表无错位（**致命 #4 验收**）
- [ ] 后端 prod 配置下 `curl POST /auth/register` 返回 404，`curl POST /auth/device-logout` 返回 401
- [ ] Apple Sign-In 按钮在 SetupScreen 已消失
- [ ] 离线写 3 条 task → 联网 → 全部同步成功
- [ ] logout user A → login user B（造一个临时账号）→ B 不会收到 A 的离线写入
- [ ] AgentScreen：触发 risky update → dismiss sheet → 主屏 banner 出现 → 点 banner 重新进 sheet → confirm 成功

### 7.4 版本号

- [ ] `MARKETING_VERSION = 1.2.4` ×2 target
- [ ] `CURRENT_PROJECT_VERSION = 1.126` ×2 target
- [ ] `backend/pyproject.toml` version = `1.2.4`
- [ ] `git tag v1.2.4` + push

---

## 8. 回滚预案

按"改动可逆性"分等级，回滚步骤越靠前越优先：

### 8.1 服务端（最高优先级）

- **触发条件**：API 出现新 5xx / 401 大量上涨。
- **步骤**：
  1. `ssh hz "cd /opt/100j/backend && git checkout v1.2.3 && systemctl restart 100j-api"`。
  2. 若 0006 迁移已 apply：`alembic downgrade -1` 把 `refresh_token_jti` 表 drop。**注意**：所有现有用户的 refresh 都会失效（因为 v1.2.3 的 refresh 路径不查 jti，但 v1.2.4 签发的 refresh 已经写过 jti；回滚后旧 refresh 仍能工作，新签发的不需要 jti 表）。
  3. 不需要回滚 P0-2 LLM key 派生：因为 `migrate_llm_keys_v124.py` 是单向的，回滚 v1.2.3 后老派生函数无法解 v1.2.4 写入的密文 → **若已 apply 迁移**，必须手动重新设置 `LLM_KEY_ENCRYPTION_SECRET` 让用户重新填 LLM key（在 README 警告此点）。
- **演练**：发布前在 `hz-db-restore-rehearsal.sh` 跑一次"升 v1.2.4 → 回滚 v1.2.3"全流程。

### 8.2 客户端

- **Widget App Group / entitlement 改动**：iOS 装机后回滚靠重装旧版本 IPA。**注意**：v1.2.4 写入的 widget snapshot 留在 App Group 容器里，v1.2.3 读不到（v1.2.3 macOS 走 per-app，iOS 走 App Group，所以 iOS 自然兼容）。
- **MutationQueue 加 user_id**：v1.2.4 的 queue 文件格式向前不兼容（新字段 `userId`）。v1.2.3 的 `MutationQueue.decode` 会因为多余字段直接 throw → 丢弃整个 queue。提前在 v1.2.4 发布 release notes 提示用户 "回滚需先确保 pending queue 为 0"。
- **应急**：v1.2.4 的 App Store 上线后保留 v1.2.3 的 IPA 至少 14 天，TestFlight 留 build 1.125。

### 8.3 部署脚本

- `scripts/deploy-hz.sh` 改动（systemd ExecStart 加 `--proxy-headers`、ALTER ROLE 参数化）回滚靠 `git revert`；改完后 `systemctl daemon-reload && systemctl restart 100j-api`。
- 反代（nginx 或 caddy）配置不动，但 X-Forwarded-For 透传必须保持开启，否则 v1.2.4 后所有限流走 127.0.0.1 共享配额（与 v1.2.3 表现一致，不会更糟）。

### 8.4 rate_limit 中间件

- 若 P0-4 的 `key_func` 在生产引发误杀（owner 自己被限），快速热补丁：把 `key_func` 改回 `get_remote_address` 并 `systemctl restart 100j-api`。新 jti / OTP throttle 不依赖 key_func，独立运行。

---

## 9. Builder 执行顺序建议（给后续施工 agent 看）

1. 开新分支 `v1.2.4-dev` from `main`。
2. 按 P0 → P1 → P2 顺序提交，每个 phase 单独一个 commit（或 squash 后命名清晰，含覆盖的问题编号）。
3. P3 / P4 可并行（不同人或不同时间槽），合到 P5 开始前。
4. P5 → P6（P6 涉及 Xcode 项目改动，建议人工介入 entitlement / project.pbxproj 部分）。
5. P7 最后一次性提：版本号 + OpenAPI snapshot + deployment.md。
6. 跑 §7.1 / §7.2 / §7.3 全部清单，全绿后 `git tag v1.2.4`、合 `main`、push origin。

---

## 变更日志

### [2026-05-24] 初版
- 初始规划完成。
- 覆盖 reviewer 报告 34 条中的 32 条；#14 / #17 明确 deferred 到 v1.2.5。
- 7 个 phase（P0–P7），按依赖图串行 + 局部并行执行。
- 版本号目标：v1.2.4 / build 1.126。

### [2026-05-24] P1 施工补充
- 变更内容：
  - `device_session_service._verify_token_or_raise` 顺手修复 SQLite 测试环境下 `expires_at` 比较抛 `TypeError`（offset-naive vs offset-aware）的历史 bug。新增 `_as_aware_utc()` 兜底。
  - `DeviceSessionStore` 由 `final class` 改为 `open class`（含 `refreshToken` / `saveRefreshToken` / `clearRefreshToken` / `info` / `recordIssued` / `clearAll` / `hasActiveSession` / `deviceId`），仅为单测能 subclass 出 hermetic stub；生产代码继续用 concrete class。
  - `AuthRepository` 由 `final` 改 `open class`，`silentResume()` 标 `open`，同上理由。
  - `AppModel` 新增 test-only DI init：`init(authMode:, api:, authRepository:, deviceSession:, startsNetworkMonitor:)`；原 `init()` 改 `convenience`。内部所有 `DeviceSessionStore.shared.*` 替换为 `deviceSessionStore` 实例字段。
  - `APIClient` 401 自动 refresh 增加 `shouldTreatUnauthorizedAsExpiredSession(path:)` 门控：`/auth/*` 路径上的 401（如 owner-login 拒签）不再误触发 refresh / retry。
  - `APIClient.refreshTokensIfPossible` 失败/无 refresh token 时**不再**主动 `tokenStore.clear()`，把清理决策交给上层 401 envelope 处理器（它已经有 cooldown 逻辑）。
  - 新增 SwiftPM test target `PersonalAffairsAppTests`，依赖 `PersonalAffairsApp` + `PersonalAffairsCore`，承载 `AppModelAuthFlowTests`。
- 变更原因：
  - SQLite tz 比较 bug 暴露于本期新增的 verify() 测试路径，不修则后端测试无法绿。
  - DeviceSessionStore / AuthRepository 不开放继承则无法写"不打开网络/Keychain"的 hermetic 测试。
  - AppModel 没有 DI 入口则无法测 `run` / `expireCloudSession`。
  - 401 refresh 的 `/auth/*` 门控修复：device session refresh 启用后，dev 机 Keychain 里的 device refresh token 会让 `/auth/owner-login` 的 401 误走 refresh→retry 路径，导致原 `testOwnerLoginUnauthorizedKeepsServerMessage` 红。
  - refreshTokensIfPossible 不再清理 store：cooldown 才有意义；否则两段清理叠加把 cooldown 绕过去。
- 影响范围：Phase P1（reviewer #1 / #6 / #8 / #12 / #25）；连带影响所有依赖 `DeviceSessionStore`/`AuthRepository` 的代码（生产层兼容，仅是放宽继承约束）。
