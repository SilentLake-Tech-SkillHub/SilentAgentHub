---
name: vercel-playwright-cicd
description: Run repeatable Playwright acceptance checks against a deployed Vercel Preview or authorized production site, archive browser evidence, and connect results to existing CI/CD gates. Use for deployed web journeys, including authenticated and streaming AI interfaces.
metadata:
  version: "1.0.0"
---

# Vercel Playwright CI/CD 页面验收

## 目标和输入

在已部署的 Vercel 页面执行真实用户流程，将可重复测试接入项目现有 CI/CD。先从项目 Router、已批准范围和验收标准取得：目标 URL、Preview/Production、部署 ID 与代码 commit、关键用户流程、账号角色、预设问题、截图/报告目录、允许的测试数据及模型调用预算。简单变更只验证受影响流程。

测试目标可以是生产页面，但部署、修改权限、删除真实数据或产生未获授权的模型费用须另有对应授权。创建 Skill 不等于授权测试或发布。

## 工具与配置

优先复用项目的 Playwright 依赖、配置和 tests，不新建第二套 CI/CD。核对本地实际 package.json 和现有测试命令后执行。测试浏览器访问部署 URL；测试执行器可以运行于本机或现有 CI runner，应用仍运行在 Vercel。

页面测试无需整体拉取生产环境变量。若 Preview 缺少服务端认证或上游配置，先确认缺失的变量名，将必要值通过获批的服务端配置方式用于候选部署；不输出值、不入 Git、不复制无关生产秘密。Playwright 不需要模型 key、OAuth 私钥或服务端签名密钥。

已有浏览器登录可使用受支持的浏览器连接方式。项目支持 Playwright 登录时，采用正常登录或已获批的专用测试账号。用户完成 Apple/短信/验证码等人工步骤后再续跑。需要保存 storageState 时只保存到 Git 忽略的私有路径，限制访问，报告不附 cookie/token，不擅自绕过认证。

Vercel 部署保护和应用登录分别检查。重定向到保护/登录页仅证明到达门禁；不能算业务接口成功。保护访问使用现有获批机制，缺少访问能力时记录 blocked，不改全局保护设置。

## 可重复测试流程

1. 固定部署身份和测试前提。优先等页面元素、网络响应或业务状态，避免用固定 sleep 判定成功。录入开始时间、环境、commit、部署 ID、viewport 和不含凭据的账号角色。
2. 使用项目选择器和可见角色/标签定位控件；对关键交互写可判定断言。按实际范围执行桌面与手机尺寸，检查溢出、输入/上传、提交、防重复发送、错误及恢复状态。
3. 对 AI 对话：发送预设题，确认用户消息出现、真实请求发出、工具状态按实际事件显示、内容逐步更新、结束事件及完整回答出现。只有首字或部分回答不得计为通过。记录首字耗时、总耗时和相关请求失败，不把内部思维链作为展示要求。
4. 对联网结果：只有实际触发搜索才要求“正在搜索”；最终相关内容旁显示来源，点击核对有效目标。数字/图表的来源、年份、口径依据产品标准验证。无搜索场景不强制显示搜索状态。
5. 对持久化：按批准范围验证刷新/重新打开、会话列表及历史可查看。仅对专用测试记录执行已授权清理；删除确认和不可恢复提示按产品要求检查，不触碰真实用户记录。
6. 保存关键步骤截图、断言结果及控制台/网络错误摘要。截图在用户对话中显式展示。含个人信息时使用专用测试账号或脱敏副本；trace、HAR 和认证状态可能带秘密，仅在必要时保存于受控私有目录，公开报告引用脱敏证据。

## CI/CD 结果与输出

沿用现有 CI 入口：离线检查 → 对应候选部署 → Playwright 验收 → 结果与截图归档 → 用户验收 → 获批生产推广 → 生产 smoke。若项目没有自动 runner，只报告“脚本可重复执行”，不能称自动 CI/CD 已接入。

CI 输出项目支持的机器报告（例如 JUnit/JSON）和人可读报告，至少包含部署身份、用例 ID、预期/实际、passed/failed/blocked/not_run、证据路径和失败原因。关键用例 failed、blocked 或未运行时门禁不得放行；测试命令返回非零。可选的暂不执行项须在范围中明确登记。

网络瞬时失败只按项目既有重试策略重试并保留首次失败；真实模型调用前核对预算，失败未知用量不得记成零成本。验收报告区分界面流程通过、内容正确性检查和用户验收。

调用 `browser-acceptance-screenshot` 管理页面证据，`project-validation` 选择最小充分验证，`git-environment-promotion` 管理已获授权的部署和推广，管理文档按项目 Router 指定控制 Skill 写入。不得因 Skill 被调用自动合并、推送或生产发布。

## 结束条件

本轮约定用例有实际结果，截图和报告可读回，失败/未执行项已登记，当前部署与代码版本对齐。若登录或配置阻塞，报告停在哪个用户动作及恢复第一步；不得把匿名首页截图或后端独立测试称为页面端到端通过。
