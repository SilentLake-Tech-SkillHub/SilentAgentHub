---
name: alipay-web-payment-deploy
description: 将支付宝电脑网站支付落地到具体项目，覆盖企业商户与应用前置检查、官方 Skill/SDK 使用、模块安装、前后端适配、环境变量与密钥、沙箱/生产切换、异步通知验签、幂等入账、退款冲退消息、排障和验收。用户提到复用支付宝支付、批量接入支付宝、电脑网站支付部署、支付宝生产切换、支付宝回调/验签/重复入账、AE150003030、支付后余额不刷新、支付宝环境变量或支付 SOP 时使用。
---

# 支付宝电脑网站支付部署

## 先确定工作分支

只选择一个分支执行：

1. **新项目接入**：从前置条件开始，安装模块并完成沙箱/生产验收。
2. **已有项目审计**：对照架构、环境、回调、账本和验收矩阵输出缺口，不直接部署。
3. **问题排查**：先记录现象、订单号、错误码、预期和实际结果，再修复并重放验证。
4. **环境迁移**：保留旧 APP ID/PID/公钥处理旧订单，设计新旧凭据迁移窗口。

本 Skill 只处理 `alipay.trade.page.pay`。其他支付宝产品先回到同目录的官方 `alipay-payment-integration` Skill 重新选型。

## 启动确认

执行新接入、生产配置或真实支付前：

1. 读取官方 `alipay-payment-integration/SKILL.md` 及其电脑网站支付、通用接口和 SDK 说明。
2. 输出完整执行步骤和完成条件。
3. 输出以下服务声明：

> 使用本服务需遵守法律法规，自行审核、测试并承担使用责任；禁止在代码、日志、文档、截图、大模型对话或公共仓库中暴露密码、API Key、应用私钥等敏感信息。

4. 明确询问：`是否同意服务声明并确认接入支付宝电脑网站支付？请回复“同意”或“确认”。`
5. 未收到确认时停止，不安装代码、不创建沙箱、不修改环境。

## 1. 审计项目

先读取项目 root/module 规则、架构、支付代码、数据库、部署方式、任务与问题记录。

确认：

- 登录用户如何映射到钱包/额度账户。
- 支付订单、事件、账本和额度分别存在哪里。
- 后端框架、静态资源目录、数据库和部署方式。
- 是否已有 PayPal/Stripe 等支付，避免复用错误的订单状态或币种。
- 是否有公网 HTTPS、备份、回滚、日志和管理员权限。

读取 [产品与架构基线](references/product-and-architecture.md)。如缺少原子或幂等额度接口，先登记阻塞，不用前端余额更新代替。

## 2. 核对人工前置条件

读取 [人工注册与维护清单](references/manual-operations.md)，逐项标记：`已完成 / 需人工 / 阻塞`。

至少需要真实来源的：企业支付宝账号、PID、APP ID、电脑网站支付签约、RSA2 应用私钥、支付宝公钥、return_url、notify_url。禁止生成、猜测或使用示例值冒充。

账号所有人必须人工完成企业认证、最终密钥上传/下载、沙箱买家登录、生产异账号付款、退款审批和结算账户维护。

## 3. 安装通用模块

先 dry-run：

```bash
python3 scripts/install_module.py --project-root /absolute/project/path
```

检查目标路径和冲突后，再在用户确认的项目执行：

```bash
python3 scripts/install_module.py --project-root /absolute/project/path --apply
```

脚本遇到已有文件会拒绝覆盖。此时手工 diff 并按项目现有边界集成，不删除用户代码。

模块位于 `assets/module/`，包括 Python 核心、JavaScript 表单提交器、环境模板、Flask 参考适配和测试。安装后必须：

- 将 `grant_credit_idempotently()` 接到真实额度/钱包服务。
- 将三个接口接入项目路由并加登录/CSRF/限流边界。
- 初始化订单、事件、账本和退款冲退表，或实现等价 repository。
- 把前端按钮接到登录态创单接口。

## 4. 配置环境和密钥

读取 [环境变量与密钥规则](references/env-and-secrets.md)。生产优先使用 secret 文件或 secret manager，不允许 inline 私钥。

验证时只输出存在性和 host：

```bash
python3 scripts/validate_env.py --env-file /secure/path/alipay.env
```

不得打印 `.env`、密钥正文、买家账号密码或 Cookie。生产私钥文件必须限制 group/others 权限，Docker 只读挂载。

## 5. 实现支付状态机

必须满足：

- 创单先持久化本地 `CREATED`，再调用 SDK `page_execute()`。
- 浏览器只提交后端返回的支付宝 form，不接受任意 action host，不执行返回 script。
- `return_url` 只读取订单号并服务端调用 `alipay.trade.query`，不信任回跳金额和状态。
- `notify_url` 无登录/CSRF，先验签，再校验 app_id、seller_id、订单、金额、状态和 trade_no。
- canonical 通知原文按 charset 编码为 bytes 后调用 SDK。
- 同步回跳和异步通知进入同一幂等入账函数。
- 外部额度系统必须按 `alipay:{trade_no}` 去重。
- 退款冲退消息解析 `biz_content` 并按 `notify_id` 去重，不自动发起退款或自动扣额度。

退款、退款查询、撤销、关单和账单下载 SDK 方法只能放在管理员 RBAC、审批和审计之后。撤销用于不确定支付状态的交易控制，关单用于关闭未支付交易，不得混用。

## 6. 沙箱验证

按 [验收与排障](references/acceptance-and-debug.md) 的分层矩阵执行：

1. 本地单测、语法、建表、配置和敏感信息扫描。
2. 沙箱创单并确认浏览器 POST 后进入官方沙箱收银台。
3. 测试人员人工输入沙箱买家账号并付款。
4. 验证服务端查询、订单、账本和额度只增加一次。
5. 重复查询/通知不得重复入账。

沙箱网关 `302` 只证明 form 被接受，不得表述为付款完成。快速沙箱不可完整证明生产 signed notify。

## 7. 生产切换

生产操作属于高风险变更。先说明影响、备份、回滚、验证和不扣款边界，等待用户明确授权。

切换顺序：

1. 备份代码、Compose、环境、secret 挂载和数据库。
2. 配置正式 APP ID/PID/私钥/支付宝公钥和官方网关。
3. 只重建支付后端，确认服务健康和 DB 检查通过。
4. 用不存在订单执行签名查询，获得可解释业务错误，证明不扣款连通。
5. 再单独申请真实小额付款授权。
6. 必须使用与收款 PID 不同的实名支付宝账号。
7. 验收 `TRADE_SUCCESS`、signed notify、事件 verified/processed、单条账本、单次额度和 Dashboard 服务端刷新。
8. 重放同一 signed notify，不得新增账本或额度。

## 8. 交付口径

按以下状态报告：

- `Partial`：只完成代码、沙箱跳转或生产签名连通。
- `Verifiable`：真实支付、查询/通知、幂等账本和额度已通过。
- `Final`：纳入范围的退款、撤销、账单下载、对账、告警和人工维护也完成。

交付时列出自动完成项、人工完成项、未验证项、生产版本、回滚点、订单/事件/账本证据和后续维护责任。不得把同步回跳入账称为异步通知闭环，也不得把支付宝国内接口称为 Alipay Global/Alipay+。
