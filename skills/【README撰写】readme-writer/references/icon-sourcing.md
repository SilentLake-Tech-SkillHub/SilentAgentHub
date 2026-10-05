# 图标采集

为"兼容生态"节采集各产品官方图标。图标是商标，仅作兼容性标注属于合理使用；不用于模仿或冒充。

## 来源优先级

1. 官网 `apple-touch-icon.png`（通常 180×180，最干净）
2. 官网 `favicon.ico` / `icon.png`（ico 需转 PNG）
3. 产品 GitHub 组织头像（`api.github.com/repos/<org>/<repo>` 的 `avatar_url`）
4. Simple Icons CDN（`cdn.simpleicons.org/<slug>`，品牌类收录全）
5. Wikimedia Commons（`commons.wikimedia.org/wiki/Special:FilePath/<文件名>?width=240`，按文件名解析，不猜哈希路径）

## 下载规则

- 带浏览器 UA；下载后**校验 MIME 是 `image/*`**——返回 HTML 页面（反爬/404 页）不算成功，删除重试下一来源。
- `.ico` 转 `.png`（macOS 用 `sips -s format png`）；JPEG/PNG 统一转正 PNG。
- 全部落库到目标项目 `docs/images/icons/`，文件名 = 产品小写连字符（`claude-code.svg`）。**不热链第三方 CDN**——README 引用本地相对路径。
- 展示规格：`<img src="..." width="18" valign="middle">` 内嵌在名称前，HTML 标签写法（GitHub 对 `valign` 有效，纯 markdown 不支持）。

## 重名歧义（最高优先规则）

通用词产品名（Cue、Muse、Dots、Pi 这类）存在大量同名产品。**搜到候选后不自行判定**，把候选列表（产品 + 出品方 + 官网）交给用户确认指向，用户答复后再取图标。取错图标比没有图标更糟。

## 同集团共用

同一出品方的多个产品（如 Codex 与 Dots 同属 OpenAI）可共用集团图标，但需在交付说明里告知用户"共用"，由用户决定是否接受。

## 降级路径

全部来源都取不到（反爬、封闭测试期无素材）时：

1. 用该产品所属公司的官方图标代替，告知用户；
2. 仍不行则留占位（首字母色块）+ 在交付说明里标注"待补"，**不猜、不用相似图标顶替**。

图标采集完成后逐张目检：是正确的品牌、方向没旋转、透明背景在白底下可见。
