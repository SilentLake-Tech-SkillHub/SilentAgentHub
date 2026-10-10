此SKILL灵感来自于天才Agent少女ASu

# Resume Authoring

Skill package version: `v0.3.5`. Resume content, Word files and PDF files retain their own approval states.

This Skill guides evidence-based resume writing and revision across different candidates. It separates content-module confirmation, editable Word review, PDF acceptance, and versioned delivery. Each run reads only the current candidate's authorized materials in that candidate's private workspace; the package contains no candidate resume or personal template.

Invoke `$resume-authoring` when preparing or revising a resume. Provide the target role, audience, source materials, and any accepted prior version. The Skill will first establish the evidence and review boundaries, then work through sections before file production.

## 子 Skill：逐项目简历审核

[`resume-project-review`](skills/resume-project-review/SKILL.md) 提供完整原文与建议稿对照、逐项目审批、保留关键方案的压缩、反馈传播及中英文分阶段交付。父 Skill 在相应任务中加载它。

[中文文档检查](skills/resume-project-review/references/chinese-quality.md) 覆盖 UTF-8、真实加粗与链接、中文字体、文字读回、全页渲染和用户报告的查看器问题。检查脚本只读取调用者提供的文件，不包含个人简历或路径。

中文排版按用户明确偏好处理；无额外间距时同时检查实际空格及Word自动中西文间距，使用`--no-cjk-latin-spaces`选项。

## 子Skill：简历压缩与篇幅路由

[`resume-compression`](skills/resume-compression/SKILL.md)承接逐项目逐句压缩、并列信息合并、关键词与事实关系保留、格式保留和实际页数检查。压缩阶段保留全部实质内容；按页数删减阶段另记完整删减范围与理由。

默认顺序：长版完整审核→压缩版→按需删减的目标页数短版。首次确认精确页数、页数上限或无固定页数；压缩版满足篇幅要求即可直接交付，超过目标则继续独立的内容取舍阶段。已确认篇幅要求写入调用者私有配置并复用，通用Skill不写死某位用户的页数。

完整原文与完整修改稿保持可审阅，默认逐项目审批；用户明确免某轮复审时，记录授权并完成该范围的自主执行和验证，后续轮次按其对应授权处理。Word与PDF分别遵从用户的交付、审批约定，语言顺序沿用用户要求。

内容源与格式基线分别登记；保留实际字体、字号、行距、段距、标题、加粗、链接及图标，逐段检查正文XML并在同一查看器中对照渲染。用户授权统一某一字号，不能扩展为整份简历的格式重设计。

## 独立默认格式模板

[`assets/default-format.json`](assets/default-format.json)单独保存默认页面、字体、字号、行距、段距、标题层级、原生加粗／链接及日期右对齐规则。使用优先级：本轮用户明确要求→用户模板或已确认格式→默认模板。先解析实际继承属性，防止姓名继承正文固定行高；日期按有效文字区统一右制表位，禁止空格凑齐。已有文件仅修复获准属性。

[`check_resume_layout.py`](skills/resume-project-review/scripts/check_resume_layout.py)检查有效固定行高与日期制表位，结果仍需全页渲染和对应查看器核验。

整体格式恢复按已选验收模板的语义角色核对列表、缩进、标题颜色、分隔线、段落节奏和页面组件，并读回实际使用成品。姓名与日期检查只覆盖对应局部属性。

对已选模板的分类与重点层级分别记录角色，按优先项目与普通项目成对核验颜色、字号与分组标题。`default-format.json`的AI重点配置仅在用户选择或其参考模板采用时启用。
