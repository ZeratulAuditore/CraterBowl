# 022: Stats (A21)

## Goal
Track per-player, per-position stats every match and show an end-of-match summary.

## How Gridiron does it
"Extensive stats system with a public leaderboard for every position" (leaderboards: A22).

## Design
`src/sim/stats.gd` (pure) listens to World events and keeps a **play context** (LOS at snap, passer, receiver, completion). It credits lines keyed by **owner|POSITION** (owner = the human controlling that athlete at the time, or "Bot"), so switching positions mid-match splits your stats correctly.
- Passing: att, comp, yds, td, int. Receiving: rec, yds, td. Rushing: car, yds, td.
- Defense: tkl, sack (QB downed behind the LOS before a pass), int, pbu, ff (forced fumble), fr (fumble recovery).
- Points: TDs credited to the scorer (6, or the Chaosball streak value via `points`).
- Yards are offense-frame gain from the LOS at the whistle (tackle / OOB / TD). Return yards after takeaways aren't counted (documented gap).
- `summary_lines(names)`: per-team totals + each human's lines; `to_dict()` for persistence (A22/A23).
- Main: a Stats per match; owner lookup via the roster (humans) or "Bot". At FINAL, the HUD shows the summary and it's printed to stdout.

## Better than Gridiron
Stats split by position automatically when you switch with TAB, so your QB numbers aren't polluted by your LB snaps.

## Acceptance criteria
- Completion 12 yd: passer 1/1, 12 yds; receiver 1 rec, 12 yds; tackler 1 tkl.
- Incomplete: att +1, comp 0. Interception: passer int, defender int. Breakup: defender pbu.
- Sack: QB downed behind LOS before throwing → sack for the tackler, no rush stats.
- Run: carry + yards; TD run: rush td + points.
- Passing TD: passer td, receiver td + points.
- Fumble: forced fumble for the diver, recovery for the recoverer.
- Owner change mid-match splits lines.
- Integration: all-bot game → total passing yards == total receiving yards, completions ≤ attempts.
