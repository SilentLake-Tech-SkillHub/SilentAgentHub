# Harness V5.2.5 内置盘部署执行计划

> Path: `流程管理/执行计划/TASK-0001_V5.2.5内置盘部署/plans.md`

## 治理信息

- 记录时间：2026-08-10T14:10:31+08:00
- 触发需求 / 事件：用户明确要求按 Codex 规则把真正运行的 Harness 部署到 Mac 内置盘的 `~/.codex` 及对应项目位置，外置盘只保留原件、历史和备份。
- 调用 Skills / plugins：`harness-router`、`deployment-router`、`project-initialization`、`doc-plan`、`project-validation`、`computer-use`。
- 当前状态：`repair_in_progress -> awaiting_acceptance`
- 关联需求 / 任务 / Decision / Plan：REQ-0001；TASK-0001。
- 本次结果：范围错误已修复；Drive 六文件和 894 文件便携交付完整落盘，系统已从完整包重装并通过 production_release 与 Mac 回滚验收。
- 下一步：等待用户验收；不自动 commit、push、tag 或远端发布。
- 最近校验：2026-08-10T15:30:41+08:00

## State

- `repair_in_progress -> awaiting_acceptance`

## Purpose

- 让 Codex 的实际运行不依赖不稳定的外置盘：系统级 Harness 固定在 `~/.codex`，项目级 Hooks、Memory 和 Harness 配置固定在内置盘的稳定 Git 项目根。

## Progress

- [x] 用户批准内置盘部署。
- [x] 核对 V5.2.5 系统级与项目级路径规则。
- [x] 创建内置盘 Git 根 `<HOME>/Documents/Codex/Agent-Harness-V5.2.5`。
- [x] 安装项目 Hooks、Harness 配置、诊断和控制器 Skills。
- [x] 初始化 Router、Memory 与必要治理记录。
- [x] 运行项目完整性和 Hook fixture。
- [x] 完成 Codex 项目信任与 7 组 Hook 信任。
- [x] 运行真实 Hook 生命周期 E2E。
- [x] 重启 Codex Desktop并读回状态。
- [x] 执行重启后的真实 Hook/Memory E2E。
- [x] 核对 V5.2.4 包完整性和旧版 Skills 在线保留。
- [x] 识别原部署把 273 文件 production 子包误当成 894 文件完整便携交付。
- [x] 从用户指定 Drive 文件夹读回六个交付文件和官方交付报告。
- [x] 下载原始 ZIP，Drive SHA-256 一致，临时解压 896 个物理文件，894/894 manifest 校验通过。
- [x] 把 Drive 六个外层文件和完整解压包保存到内置盘项目。
- [x] 从完整便携包重新安装系统运行子集并保留旧版/自定义 Skills。
- [x] 执行 production_release 全量验证和重启后 E2E；完整包重装后的运行资产与重启时加载资产逐文件一致，四项 E2E 再次通过。
- [x] 清理未被生产指针引用的 V5.2.5 嵌套重复副本，并保留废纸篓恢复路径。
- [x] 按用户授权建立内置盘项目的本地首次 Git 基线；不配置远端、不 push。
- [ ] 用户明确验收后关闭部署记录。

## Context

- 系统级根：`<HOME>/.codex`。
- 系统生产身份：V5.2.5；AGENTS SHA-256 已与版本包一致。
- 项目级运行根：`<HOME>/Documents/Codex/Agent-Harness-V5.2.5`。
- 外置盘目录只作为 Drive 原件、历史版本和部署备份，不再作为 Hook 运行依赖。
- 当前项目是 Harness 运行与验收工作区，不启用代码模块，`sourceLayoutRequired=false`。

## Plan of Work

1. 保持 `~/.codex/AGENTS.md`、`~/.codex/skills/`、`~/.codex/harness/V5.2.5` 和生产指针作为系统级部署。
2. 使用 V5.2.5 `install-harness-assets.ps1` 向内置盘项目安装 `.codex/hooks.json`、Hooks、Harness JSON/Schema 和按需诊断。
3. 从同一不可变 V5.2.5 包安装项目控制器 `SKILLS/`，建立 Router、Memory、任务、问题、风险、运维、验证、验收、版本和历史索引。
4. 在自动历史迁移关闭状态下运行所有完整性检查和 4 项 Hook fixture。
5. 使用 Codex 自带 Hooks 管理界面持久化信任，重启 Desktop，随后执行重启后的真实项目 Hook 生命周期。
6. 验收通过后启用自动历史迁移并复验；不自动 commit、push 或上传。
7. 修复范围错误：以 Drive ZIP 顶层 `manifest.json` 的 894 文件为完整交付事实源，在项目内保存完整便携包；系统运行只按 `AI_DEPLOYMENT_GUIDE.md` 安装 `production/V5.2.5`、`rollback/V5.2.4` 和 81 个托管 Skills。

## Validation

- 系统：AGENTS、两个 current 指针、V5.2.5 manifest、81 个托管 Skills。
- 项目：Git 根、JSON/Schema、Hook 注册、22 个生产脚本、3 个 Hook tests、项目控制器完整性。
- Runtime：source-layout、Memory、Plan disclosure、document controller、lifecycle、history。
- E2E：query routing、plan disclosure、Memory Desktop、runtime performance，以及重启后的真实 Hook 事件。

## Decision Log

- 2026-08-10：系统级资产保持在 `~/.codex`；项目级资产按规则跟随稳定内置盘 Git 根，不放入外置盘运行。
- 2026-08-10：内置盘运行项目采用 `<HOME>/Documents/Codex/Agent-Harness-V5.2.5`，外置盘只保留归档。
- 2026-08-10：不复制系统级 AGENTS 到项目根；项目没有额外规则时不创建重复的项目 AGENTS/CLAUDE 镜像。
- 2026-08-10：本地首次提交使用仓库级身份 `Codex <codex@local>`，只为该内置盘项目建立可恢复基线，不改变全局 Git 身份。

## Surprises & Discoveries

- V5.2.5 项目模板的控制器注册表引用项目 `SKILLS/`，但模板安装器未自动复制 `skills-source/`；本项目会从同一版本包精确安装并验证。
- 包内部分 fixture 使用 Windows 常见的 `powershell.exe` 与 `$env:TEMP`；macOS 验收使用临时适配器与 `/private/tmp`，生产 Hook 仍直接使用 `pwsh`。
- 通用 `check_harness.ps1` 固定要求可选的 `知识管理/KnowledgeRouter.md`；本项目未启用知识管理，因此按项目初始化规则记为不适用，以六项 V5.2.5 专项完整性检查替代。
- retention 首次启用发现风险清单缺少归档契约表头；补齐 `编号` 与 `状态` 字段后，归档器和完整性检查均通过。
- 原验收只证明 `production/V5.2.5` 子包 273/273 完整，没有证明 Drive 便携交付 894/894 完整；用户指出后已撤销“技术无缺口”结论并进入修复。
- Drive 原始 `Rollback-Harness.ps1` 使用 Windows 反斜杠做路径包含判断，在 macOS 会误报安全路径；原包保持 894/894 不变，另在 `tools/macos-harness/` 部署跨平台适配并通过隔离真实回滚。

## Outcomes & Retrospective

- 重启后的真实 E2E 返回 `POST_RESTART_HOOK_OK`；测试 conversation 状态为 `completed`、位置为 `long`，运行事件累计 11 条。
- V5.2.4 不可变回滚包 271/271 文件 Hash 一致；81 个旧版 Skill 目录无删除，226 个旧版 Skill 文件路径全部仍在当前 `~/.codex/skills`。
- Drive 六文件、ZIP SHA、894/894 顶层清单、896 个物理文件、完整安装器、81 个托管 Skills、11 个附加 Skills及 Mac 实际回滚均已验证。
- 技术验证已完成；按门禁保持 Verifiable，等待用户明确验收后再标记 Final。
- 非活动嵌套副本已移入废纸篓；项目已建立本地 Git 基线，仍未配置远端、tag 或 push。
