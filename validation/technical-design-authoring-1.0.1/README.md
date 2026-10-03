# 技术方案Skill的Harness接入1.0.1

2026-10-03；触发：用户要求核对存放、启动条件及文件调用关系，安全内嵌Harness，更新GitHub和本地。关联[Issue #14](https://github.com/SilentLake-Tech-SkillHub/SilentAgentHub/issues/14)；基线a7f559dc386ed4f429fe0b76978d15a2be2a1e98。调用Skills：harness-router、skill-creator、technical-design-authoring（本接入的设计/作者评审）、project-validation、code-review-closeout、git-environment-promotion、management-record-sync。状态：接入已实施，验证及远端读回见本次结果。

## 用户结果与实现

之前只有两上层Skill会调用新能力，根规则未登记；版本包还带旧根规则和过期Hash，可能使以后安装又回到提前Plan的流程。本次将当前已批准根规则同步到包，并在根入口登记技术方案/评审Skill。安装更新保持已有Skill更新闭环规则；五个相关Skill源、包、安装副本定向同步，其他Hooks与Skill保留。

位置和调用链见[接入合同](../../skills/【技术方案与评审】technical-design-authoring/references/harness-integration.md)。调用顺序：根规则/工作流入口 → harness-router定位当前需求、版本、注册表 → technical-design-authoring按写作或评审模式读取参考 → 各自注册的文档控制Skill留痕 → 用户技术评审决定 → plan-orchestrator工程Plan。skill-library-router提供能力选择入口；Plan不能反向代替需求或批准。

Skill可显式调用或自动发现。它是Agent指令能力，没有新设后台Hook、模型API或强制全流程自动执行。未来主机是否实际选中该Skill仍取决于请求和宿主，静态引用及Hash验证不声称每种自然语言都已经自动触发。

## 作者技术评审

发现并修复三处：根入口缺失；版本包根规则仍是旧流程且Hash过期；详细设计/评审文件不能一律声称归doc-architecture/doc-code-review所有。接入文档现要求读取项目注册表，ARCHITECTURE与CodeReview仅维护各自摘要/流水，不越权接管所有自定义文件。恢复基线只含本次触及文件，保留根部已批准增量，避免整包覆写。作者评审用于本次已授权接入的检查，不代用户业务技术评审。

人工路由核对：撰写技术方案→设计模式；评审方案→评审模式且区分作者自查/用户批准；询问当前状态/位置→只读证据且不建Plan；批准后的工程→Plan读取已批准方案；未通过技术评审→返回方案/待决问题；用户选择有界Demo→原例外仍成立，不把Demo当全产品批准。这是作者按实际入口的语义核对，不是独立模型eval。此前R.ai及非AI真实写作验证保持有效，本补丁只补接入。

## 验证与安全

采用simple_change：单一Harness调用链的低风险指令/文件同步补丁，沿已批准Skill工程继续，plan_required:false；没有新架构、Hook或业务范围。五个受影响Skill做结构校验；verify_integration.py校验相对参考可访问、源/包/安装四副本、五份根规则、两个manifest的受影响行和current指针Hash。仅定向校验本补丁，历史无关manifest项不宣称已验证。

运行：`python verify_integration.py --source <SilentAgentHub> --codex-home <Codex目录> --output copy-hashes.json`。命令不发网络请求、不读取凭据、不改变文件（仅可选输出验证报告）。本地备份位置记录在current.json的lastIntegration.backup；公开仓库只保留通用位置，不公开个人绝对路径、认证、会话或Memory。

回滚：先比对备份后的新改动，再按baseline.json仅恢复所列已存在文件；仅删除本次新建且没有后续改动的文件，恢复受影响manifest/current字段。隔离副本演练结果见验证结果；不执行git reset、不整体重装。

发布时仅提交本补丁，用户未跟踪readme-writer及RankLab应用不在范围。版本身份仍为根规则V5.2.6、包V5.2.5，新增技术方案接入补丁1.0.1；这不是整套Harness大版本发布。
