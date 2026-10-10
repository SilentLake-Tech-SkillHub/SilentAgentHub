# 当前本地运行版本：2026-10-11

这是供另一台干净机器检出并修复的版本快照，保留当前实际运行状态中的代码差异。它不是“已修复”或“已验证可直接部署”的新稳定版。原仓库内容完整保留，修复本机问题时先读本目录，而不是只根据旧V5.2.5模板猜测本机内容。

## 包含什么

- codex-home/：当前Codex根规则、PLANS与旧CLAUDE入口、88套实际安装的Harness Skills、8套模板；V5.2.5完整安装包、V5.2.4回滚包、Mac适配层、适配所引用的恢复备份、实际部署备份、安装回执与两份生产指针。
- project-template/：实际项目的25个Hook/测试文件、Hook配置、静态Harness配置，以及用于干净环境的空Memory/日志模板。
- job-skills/：当前本地job-application-assistant、campus-job-application、计划盘点、偏好确认包，包含本地README版本。
- provenance.json：复制来源身份、每个原始/发布文件Hash、路径占位替换、19项私有/运行状态排除记录。
- dependency-inventory.json：当前插件启用信息；第三方插件由其原分发渠道安装，不包含账号/凭据或自动信任记录。
- SHA256SUMS.json、verify_snapshot.py：克隆后逐文件检查，包含.env.example模板，不依赖PowerShell。

实际Memory对话、运行日志、申请资料及凭据未公开。它们不属于干净安装所需程序；目录结构和状态模板在包中保留。需要真实私有状态复现时，应在私有通道另提供脱敏样例，不能把公开快照当成完整个人机器备份。

## 另一台机器怎样开始

```bash
git clone https://github.com/SilentLake-Tech-SkillHub/SilentAgentHub.git
cd SilentAgentHub
git checkout local-runtime-20261011
python3 runtime-snapshots/current-local-20261011/verify_snapshot.py
```

随后让Agent先读取本README、KNOWN_ISSUES.md和provenance.json。修复对象是本快照中真实运行的代码及仓库对应源，不要用旧包覆盖这些差异后再诊断。原始V5.2.5包、当前实际Skills、Mac overlay、当前项目Hook和回滚材料分别保留，以支持对照。

在新工作目录先进行隔离复现和修复，不直接复制到系统Codex目录、不自动应用安装回执/旧生产指针、不自动信任Hook。旧指针、旧入口和旧清单是历史证据，文件存在不代表应启用。修复与真实环境验证通过后再生成一致的发布包、安装器和迁移结果。

元数据中的原机器路径已替换为<HOME>、<PROJECT_ROOT>、<WORKSPACE_VOLUME>或<WINDOWS_HOME>。这些是明确的路径映射，原始Hash与发布Hash都在provenance里；新机器不能把占位符直接当成有效路径。

## 版本边界

本次仅保存并发布现有本地版本，没有修复Memory竞态、PowerShell缓存、校验器或提前收尾问题；不能因快照Hash通过就关闭这些业务缺陷。完整克隆的Git历史仍保留原源仓旧入口、manifest和模板。
