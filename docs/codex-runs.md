## 2026-11-25

- Landed C08a defensive playbook (`153552b`) and C08b defensive play selection and synchronization (`9ed6fee`).
- 204 unit tests and full headless smoke passed. With multiple checkouts active, the first smoke run detected a change to shared settings. Subsequent checks used isolated user data, including a full rerun after the graphics merge.
- C08c and B03 remain open for assignments, bot behavior, play art, and the huddle. No items were skipped or stashed.

## 2026-11-25 — Defensive gameplay and huddle

- Landed C08c and B03 together (`8e823de`). Verified 208 unit tests, full headless smoke including remote recall, and offscreen captures for both teams.
- The first final smoke attempt hit a fixed matchmaker port conflict. The retry passed with isolated user data. B09 and C02 were already claimed by the kicking-game branch.

## 2026-11-27

Six backlog issues reached separate PRs against merged main. Each branch passed the full `./scripts/check.sh` gate, and each PR includes inspected offscreen captures. The issues remain open for owner review and merge.

| Issue | PR | Commit | Unit tests | GitHub Actions at handoff |
|---|---|---|---:|---|
| [#293](https://github.com/bpenwell/CraterBowl/issues/293) Keep rushing credit with the original runner | [#325](https://github.com/bpenwell/CraterBowl/pull/325) | `d2e92e8` | 549 | [Passed](https://github.com/bpenwell/CraterBowl/actions/runs/45963810146) |
| [#308](https://github.com/bpenwell/CraterBowl/issues/308) Resume searching when a host order expires | [#327](https://github.com/bpenwell/CraterBowl/pull/327) | `759c11b` | 547 | [Passed](https://github.com/bpenwell/CraterBowl/actions/runs/45964795180) |
| [#312](https://github.com/bpenwell/CraterBowl/issues/312) Close passing once a Classic runner crosses the line | [#328](https://github.com/bpenwell/CraterBowl/pull/328) | `5f21ee5` | 550 | [Passed](https://github.com/bpenwell/CraterBowl/actions/runs/45965873225) |
| [#324](https://github.com/bpenwell/CraterBowl/issues/324) Return a failure when the branch capture fails | [#330](https://github.com/bpenwell/CraterBowl/pull/330) | `f45c117` | 546 | [Passed](https://github.com/bpenwell/CraterBowl/actions/runs/45966770556) |
| [#329](https://github.com/bpenwell/CraterBowl/issues/329) Report failed comparison writes | [#332](https://github.com/bpenwell/CraterBowl/pull/332) | `daed526` | 547 | [Running](https://github.com/bpenwell/CraterBowl/actions/runs/45968269647) |
| [#254](https://github.com/bpenwell/CraterBowl/issues/254) Enforce intentional grounding under pressure | [#334](https://github.com/bpenwell/CraterBowl/pull/334) | `43d4f12` | 549 | [Running](https://github.com/bpenwell/CraterBowl/actions/runs/45969281566) |

- Opened follow-ups #322, #323, #324, #326, #329, #331 and #333. #324 and #329 reached the PRs above in this run. #335 tracks this entry.
- Skipped #110 because it was blocked, #135 and #273 because they were claimed, #298 because it overlaps the claimed Controls redesign #134, and #323 because it overlaps the rushing-credit code in #325.
- PRs #327, #328 and #334 each start from protocol v4. After one merges, the remaining protocol changes need sequential version bumps and verification against updated main.
- The first full gate on #293 was interrupted during matchmaking. The detached retry passed. The initial checkout was clean and the run added no stashes. The repo records iteration details in PRs since #112 retired `ITERATIONS.md`.
