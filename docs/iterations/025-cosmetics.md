# 025: Cosmetics (A24)

## Goal
Earnable cosmetics with zero gameplay effect, plus character customization visible to everyone in the match.

## How Gridiron does it
"Cosmetics purchasable and earnable through play, no gameplay effect; character customization." (We do earnable-only; no store.)

## Design
- `src/sim/cosmetics.gd` (pure):
  - **Catalog** by slot: `trim` (jersey accent color), `helmet` (stripe color), `number` (0–99, always free), `celebration` (TD animation: none/spin/hop/flip), `badge` (from ranked season rewards).
  - **Unlocks:** free defaults; level unlocks (level = xp / 500); badges unlock from `S<id>-<TIER>` ranked rewards.
  - **XP award** per match from your stats line: 100 played + 50 win + 25/TD + 1 per 10 yds + 10/tackle + 30/INT + 20/sack.
  - **Profile** {xp, equipped} in `user://profile.json`; `equip(slot, id)` only if unlocked; `sanitize_look()` (server side) drops unknown ids/out-of-range numbers.
- **Sync:** the client sends `{"a":"look", look}` after assignment; the host validates and stores looks per athlete and broadcasts a reliable `looks` event to all (also when assignments change). Offline: your profile look applies directly.
- **Views only:** `player.gd` gets a trim band, a helmet + stripe, a jersey number (Label3D), and a celebration animation on your TD. The sim never sees looks.
- **Earning:** at FINAL, the host broadcasts `awards` {name: xp}; every machine credits only its own player's local profile. Ranked season rewards become badges.
- CLI: `-- --equip=trim:ember,helmet:gold,number:88,celebration:spin` (persists if unlocked), `--profile-file=PATH`. (Menus: A27.)

## Better than Gridiron
No paywall: everything is earned by playing, and stats-driven XP rewards good play, not just time spent.

## Acceptance criteria
- Defaults unlocked at level 0; level items locked until enough XP; badges only with the matching reward.
- XP award formula; level from XP.
- equip rejects locked/unknown items; sanitize_look clamps the number and drops unknown ids.
- Profile save/load round-trip.
- Looks never affect the sim (identical world stepping with different looks).
- Flow: equipped number + trim visible on your view; the TD celebration plays.
- Net: client look (#88) round-trips through the host to its own view.
