# MEMORY Rules

## 治理信息

- 记录时间：
- 触发需求 / 事件：
- 调用 Skills / plugins：
- 当前状态：
- 关联记录：
- 本次结果：
- 下一步：

## 文件与职责

- MEMORY.md：本规则。
- SHORT_MEMORY.md：未关闭 conversation 最近 5 轮和 rolling summary。
- LONG_MEMORY.md：已关闭 conversation，默认 cold。

## 状态

- received
- working
- verifying
- completed
- needs_user
- blocked
- cancelled
- superseded
- closed_unresolved

## 迁移规则

只有 completed、cancelled、superseded、经用户确认的 closed_unresolved 进入 LONG_MEMORY。

## 读取规则

默认只读取当前 conversation 的 SHORT_MEMORY；Short miss 后调用 long-memory-retriever。

## 安全与 Git

三份文件进入项目 Git。Prompt 入库前必须脱敏，锁和未完成事务不得泄露敏感内容。

