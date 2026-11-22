# London Job Hunt

Personal job-search app, published as a Claude artifact: https://claude.ai/artifact/TpXgjXzW1z4mEyk4svUWBF

- **Applications**: kanban read live from the Notion *Applications* database (drag to change status), with follow-up nudges.
- **Job finder**: roles from the London CSM, London PM and UK public sector job agents (`data/leads.json`).
- **Companies**: competitor lookup via Claude, LinkedIn recruiter searches, intro drafts, and contact logging to Notion *Outreach & messages*.
- **Stats**: weekly applications, stage counts, CSM vs Product split.

The page only works fully inside claude.ai (Notion and Claude calls go through the artifact runtime).

## Files

| Path | What it is |
| --- | --- |
| `index.html` | The whole page |
| `data/leads.json` | Finder roles, rebuilt daily |
| `data/logos.json` | Company icons as data URIs (keyed by domain) |
| `data/domains.json` | Company name → website domain, used for logos |
| `data/prep.json` | Interview-prep links shown on matching cards |
| `tools/build-data.ps1` | Rebuilds `leads.json` and `logos.json` from the three job-agent pages |

## Rebuild the finder data

```powershell
.\tools\build-data.ps1 -Csm <csm.html> -Pm <pm.html> -Pub <pub.html>
```

Each input is the saved HTML of one job-agent artifact. Then republish the artifact with `index.html` plus the `data/` files.
