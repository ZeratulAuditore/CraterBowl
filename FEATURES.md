# Feature backlog → moved to GitHub issues

As of 2026-11-25 the backlog lives in **GitHub issues** on `bpenwell/CraterBowl` (migration: issue #1). Don't add items here.

- How to find, claim, update and close work: `docs/workflow.md`
- Old ids (`A##`, `B##`, `C##`, `D##`) → issue numbers: `docs/backlog/legacy-ids.md`
- What's shipped and how it plays: `docs/features/`; history: merged PRs and `git log`

```bash
gh issue list --label P0 --search "-label:status:in-progress sort:created-asc"   # next work
gh issue create --label "type:bug,P1,area:<x>" --title "..." --body "..."        # found something
```

If a merge from an older branch conflicts here (for example a branch checking off `B09`), keep this stub and update the issue with `gh` instead.
