---
name: rednote-searching-engine
description: Search Xiaohongshu/RedNote for user-specified topics, collect relevant text notes and high-liked comments, rank notes by relevance and likes within the requested time window, preserve login through a persistent browser profile, and produce Markdown research reports. Use when the user asks for 小红书, Xiaohongshu, RedNote, XHS, 红书, 小红书评论, 小红书评价, consumer feedback, comment mining, review collection, social listening, or Markdown summaries from Xiaohongshu posts/comments.
---

# Rednote Searching Engine

## Goal

Collect Xiaohongshu text-note evidence for a user topic and deliver a Markdown report containing:

- 3-5 searched keywords derived from the request.
- Top 20 relevant notes from the requested time window, sorted by note like count descending after relevance screening.
- For each note: link, publish time, like count, author if visible, concise content summary, and top 20 visible comments sorted by comment like count.
- Clear caveats for login, unavailable comments, hidden like counts, or collection limits.

## Operating Rules

- Use a persistent browser profile for Xiaohongshu login state. Prefer `$HOME/.codex/browser-profiles/rednote-searching-engine/` unless the active browser tool requires another profile location.
- On first use, open `https://www.xiaohongshu.com/`, ask the user to scan the QR code, and wait until the logged-in home/search page is visible. Do not ask for passwords, cookies, tokens, or SMS codes.
- Reuse the same browser profile on later runs. If the session expired, ask the user to scan again.
- Do not bypass captchas, anti-bot checks, paywalls, privacy controls, rate limits, or platform access restrictions.
- Collect only content visible to the logged-in user. Do not access private messages, private accounts, or non-public data.
- Paraphrase note/comment content in the final report. Keep direct quotes short and only when needed as evidence.
- Record uncertainty explicitly when publish time, like count, comment like count, or full comments are not visible.

## Workflow

1. Clarify the topic only if the request is too broad to produce meaningful keywords. Otherwise proceed.
2. Generate 3-5 Chinese search keywords:
   - Include the core object or brand/category.
   - Include评价, 评论, 避雷, 真实体验, 推荐, or comparable intent words when relevant.
   - Avoid overly generic keywords that will drown the result set.
3. Search each keyword in Xiaohongshu.
4. Prefer text notes. Skip videos/live/shop pages unless the user explicitly asks for them.
5. Build a candidate table with note URL, title/summary, visible publish time, visible like count, keyword source, and relevance notes.
   - Preserve both the canonical `/explore/<id>` URL and the tokenized search-result detail URL when visible.
   - Prefer opening the tokenized `search_result/<id>?xsec_token=...` URL for detail collection; direct canonical URLs may be blocked by Xiaohongshu with "当前笔记暂时无法浏览".
6. Filter by the user-requested time window. If the user does not specify one, default to the last six months relative to the collection date. If Xiaohongshu only shows relative dates, convert carefully and mark approximate dates.
7. Sort remaining relevant candidates by like count descending. Keep enough candidates to withstand duplicates and unavailable pages, then collect the top 20 notes.
8. Open each selected note and collect:
   - canonical URL
   - title or first line
   - author/display name if visible
   - publish time/date if visible
   - note like count if visible
   - content summary
   - top 20 visible comments sorted by comment like count, including commenter, comment summary, like count, and date/time if visible
9. Save structured evidence as JSON using the schema in `references/data_contract.md`.
10. Generate the Markdown report with `scripts/rednote_report.py`.
11. In the final response, include the report path, collection date, number of keywords searched, number of notes collected, and any collection limits.

## Browser Collection Guidance

- Use whichever browser automation tool is available in the current environment. If both Chrome and in-app browser tools exist, prefer Chrome when the user's existing login state matters; otherwise use a persistent profile dedicated to this skill.
- Scroll slowly and wait for dynamic content to load. Avoid high-frequency automated requests.
- Open note links in separate tabs only as needed. Deduplicate canonical URLs before selecting the top 20.
- On search result pages, capture the actual card/detail anchor containing `xsec_token`. Use it for page opening, while keeping the canonical note URL as the stable source identifier.
- If a note page shows more comments behind "展开", "更多", or similar controls, load only enough to identify the visible top-liked comments. Do not attempt hidden API extraction unless the user explicitly authorizes compliant API use and access is clearly allowed.
- When like counts use Chinese compact units, normalize them in JSON where possible: `1.2万` -> `12000`, `3千` -> `3000`. Preserve the raw text in a separate field when uncertain.

## Markdown Output

Use the bundled script after collection:

```bash
python3 rednote-searching-engine/scripts/rednote_report.py \
  --input /path/to/rednote_evidence.json \
  --output /path/to/小红书评论搜索_主题_YYYYMMDD.md \
  --strict
```

If the current working directory differs from the skill directory, use the absolute script path.

The script validates the JSON shape, sorts notes and comments, limits notes/comments to 20, and writes a Markdown report with source links and caveats. Read `references/data_contract.md` when constructing or debugging the JSON.

## Acceptance Checklist

- Login state is handled through a persistent browser profile; no secrets are copied into files.
- 3-5 keywords are listed in the report.
- Candidate notes are limited to the requested time window, defaulting to the last six months where dates are visible or reasonably inferable.
- Selected notes are relevant and sorted by normalized like count descending.
- Up to 20 notes and up to 20 comments per note are included.
- The report is Markdown and includes source URLs, collection limits, and uncertainty notes.
