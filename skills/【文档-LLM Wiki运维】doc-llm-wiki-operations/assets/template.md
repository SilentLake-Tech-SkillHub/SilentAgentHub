# LLM Wiki 使用与运维

## 治理信息

- 记录时间：
- 触发需求 / 事件：
- 调用 Skills / plugins：
- 当前状态：
- 关联记录：
- 本次结果：
- 下一步：

## 启动与身份

检查 desktop、API enabled、health、major version、auth 和 project ID。

## 查询

search → files/content；引用命中 wiki 路径并区分 raw source。

## 摄入

用户批准来源 → desktop/同步到 raw/sources → sources/rescan → 等待队列 → 回读 index、log、来源摘要、链接和 Review。

## Review 与 Lint

检查 unresolved Review、孤立页面、矛盾、陈旧内容、缺失来源和索引一致性。

## 故障与降级

不可用时使用项目知识，记录待同步，不虚报成功。

## 安全

只保存 token Secret 引用，不保存真实 token。

