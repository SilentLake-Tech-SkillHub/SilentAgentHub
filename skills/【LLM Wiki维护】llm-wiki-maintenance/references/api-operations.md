# LLM Wiki API v1 operations

Source contract: `nashsu/llm_wiki` and `nashsu/llm_wiki_skill`. Verify `/health` before relying on these examples because the API may evolve.

PowerShell setup:

```powershell
$env:LLM_WIKI_API_TOKEN = '<secret-from-LLM-Wiki-settings>'
$base = 'http://127.0.0.1:19828/api/v1'
$headers = @{ Authorization = "Bearer $env:LLM_WIKI_API_TOKEN" }
```

Health and identity:

```powershell
Invoke-RestMethod "$base/health"
Invoke-RestMethod "$base/projects" -Headers $headers
```

Ingest or refresh is a two-step operation: import/copy the approved source into `raw/sources/`, then trigger the documented rescan endpoint.

```powershell
Invoke-RestMethod "$base/projects/current/sources/rescan" -Method Post -Headers $headers
```

Query and read:

```powershell
$body = @{ query = 'question'; topK = 8 } | ConvertTo-Json
Invoke-RestMethod "$base/projects/current/search" -Method Post -Headers $headers -ContentType 'application/json' -Body $body
Invoke-RestMethod "$base/projects/current/files/content?path=wiki/index.md" -Headers $headers
```

Validation and review:

```powershell
Invoke-RestMethod "$base/projects/current/files" -Headers $headers
Invoke-RestMethod "$base/projects/current/graph" -Headers $headers
Invoke-RestMethod "$base/projects/current/reviews?status=unresolved" -Headers $headers
```

Use the desktop application's Lint view for its built-in lint operation; API v1 does not document a lint endpoint. A successful rescan response is not ingestion acceptance: verify generated pages, index, log, links, citations, and unresolved review items.
