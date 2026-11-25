# 030: Achievements (D04, parity G23)

## Goal
Milestone achievements unlocked through play, persisted in your profile, with an XP bonus each.

## How Gridiron does it
Steam lists "Achievements" among Gridiron's features. Ours are original milestones.

## Design
- `src/sim/achievements.gd` (pure): catalog of {id, name, desc, xp} + predicate over a **match context** {line (your merged stats), won, deficit (biggest deficit your team overcame), rating, games, mode}. `evaluate(ctx, already)` returns only new unlocks.
  first_td, first_win, gunslinger (300+ pass yds), sure_hands (8+ rec), workhorse (100+ rush yds), sack_artist (3+ sacks), lockdown (2+ INT), pick_six (defensive TD), perfect_chaos (a 7-point Chaosball TD), comeback (win after trailing by 14+), gold_tier (ranked rating ≥ 1300), iron_man (10 matches).
- Stats gains `def_td` (TD scored by the non-offense team's carrier) and `max_td_pts` (largest single-TD value).
- Match tracks `max_deficit[team]`.
- Profile (cosmetics.gd) gains `achievements` + `games`.
- Main: at FINAL the host computes ranked first, then a context per human name and broadcasts `awards` {xp, ctx}. Every machine evaluates only its own player against its own profile and saves. HUD: "ACHIEVEMENTS: …".

## Acceptance criteria
- Each predicate fires at its threshold and not below; evaluate skips already-unlocked; bonus XP sums.
- Stats: a pick-six records def_td + pts; a Chaosball 7-pointer records max_td_pts 7.
- Match max_deficit tracks the worst trailing margin.
- Profile round-trip keeps achievements + games.
- Flow: a real match with your TD + a win → First Touchdown + First Win unlocked, shown on the HUD, saved (temp profile).
