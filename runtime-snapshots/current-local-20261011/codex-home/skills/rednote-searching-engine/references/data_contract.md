# Rednote Search Evidence Contract

Use this JSON contract before running `scripts/rednote_report.py`.

## Required Top-Level Shape

```json
{
  "topic": "用户原始需求或研究主题",
  "generated_at": "2026-06-26T12:00:00+08:00",
  "collection_date": "2026-06-26",
  "keywords": ["关键词1", "关键词2", "关键词3"],
  "collection_limits": ["只采集可见评论", "部分帖子未显示精确发布时间"],
  "notes": []
}
```

## Note Object

```json
{
  "url": "https://www.xiaohongshu.com/explore/...",
  "detail_url": "https://www.xiaohongshu.com/search_result/...?xsec_token=...",
  "title": "帖子标题或首行",
  "author": "可见作者名",
  "published_at": "2026-03-15",
  "published_at_raw": "3月15日",
  "keyword": "触发该帖子进入候选集的关键词",
  "relevance": "为什么与用户需求相关",
  "like_count": 12000,
  "like_count_raw": "1.2万",
  "content_summary": "对帖子内容的简明转述，不要大段复制原文。",
  "evidence_notes": ["时间为页面显示推断", "评论区只加载到前50条"],
  "comments": []
}
```

## Comment Object

```json
{
  "author": "评论者可见名",
  "published_at": "2026-04-01",
  "published_at_raw": "4-1",
  "like_count": 356,
  "like_count_raw": "356",
  "summary": "评论观点转述",
  "quote": "可选的短引文",
  "sentiment": "positive | neutral | negative | mixed | unknown"
}
```

## Field Rules

- `keywords` must contain 3-5 entries.
- `notes` may contain more than 20 raw entries, but the renderer outputs only the top 20 after sorting.
- `url`, `published_at` or `published_at_raw`, `like_count` or `like_count_raw`, and `content_summary` should be present for each selected note when visible.
- `detail_url` is optional but recommended when the search result page exposes a tokenized `search_result/<id>?xsec_token=...` link. Use `detail_url` for opening the page, and keep `url` as the canonical source link when possible.
- `like_count` and comment `like_count` should be numeric when possible. If only raw text exists, keep `like_count_raw` and omit or set numeric `like_count` to `null`.
- Use ISO dates (`YYYY-MM-DD`) whenever exact dates are available.
- Keep `quote` short. Prefer `summary` for user-generated content.
- Use `collection_limits` and `evidence_notes` to surface missing dates, hidden likes, login walls, unavailable comments, deduplication, or manual judgment.
