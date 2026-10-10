# Harness 按需性能诊断

本目录不是生产 Hook。只有人工执行脚本时才读取已有的 `.codex/harness/runtime-events.jsonl`，不会被 `.codex/hooks.json` 自动调用。

## 使用

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/diagnostics/runtime-performance.ps1 -Root <项目根>
```

可选参数：

- `-ConversationId` / `-TurnId`：只分析指定对话或轮次。
- `-GapWarnMs`：异常事件空窗阈值，默认 300000 毫秒。
- `-OutputPath`：把 JSON 报告写入指定路径。
- `-LogPath`：读取非默认 JSONL 文件。

## 输出与边界

输出事件数量、可观测时间跨度、最长事件空窗、工具/事件分布、写入事件数，以及旧版日志中可配对的工具耗时。脚本只读日志，不写入新的运行事件。

项目事件日志无法观察模型请求开始、首 Token、模型完成或私有推理时间；报告会将模型耗时明确标记为 `unavailable`。不得用可观测事件跨度冒充模型耗时。

日志与报告不得包含 Prompt、工具参数、Secret、Token、Cookie 或模型推理内容。
