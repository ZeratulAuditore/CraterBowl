# 021: Chaosball scoring (A20)

## Goal
Chaosball rewards passing: a pass streak raises a touchdown's value (cap 7), and a pass clock stops ball-hogging, because the ball explodes if held too long.

## How Gridiron does it
"Pass streak: more passes raise streak; higher streak = more points per touchdown, capped at 7. Pass clock: holding the ball too long makes it explode."

## Design (World, chaos rules only)
- `streak`: completed catches by a **teammate** of the thrower (+1 each). **Self-catches don't count** (otherwise lobbing to yourself would farm points). An opponent catch (interception) resets it to 0 for the new possessing team. It resets each possession.
- **TD value** = min(2 + streak, 7): a solo run is worth 2, and 5+ completions max it at 7.
- **Pass clock:** `hold_t` counts while anyone holds the ball during LIVE; it resets on every catch. At 5.0 s → "explode": ball dead, carrier knocked down, turnover at the spot (Match treats it like an incomplete by the holder's team).
- TD event carries `streak`; Match awards the streak value in Chaosball.
- Snapshot carries streak + hold time so clients' HUDs match.
- AI: a carrier passes to its most open teammate when pressured **or** when the pass clock has < 1.2 s left.
- HUD: "STREAK 3 → TD 5 | BALL 2.4s".

## Better than Gridiron
Self-catch doesn't farm the streak, so the mode rewards real teamwork. Bots respect the pass clock, so they model good habits.

## Acceptance criteria
- Teammate catch → streak +1; self-catch → no change; interception → 0.
- TD value: streak 0 → 2, 3 → 5, 9 → 7.
- Holding 5 s → "explode", DEAD, Match turnover to the other team; a catch resets the clock.
- Classic rules never explode and award 6 per TD.
- AI carrier with no pressure still passes before the clock expires.
- Snapshot round-trip carries streak/hold time.
