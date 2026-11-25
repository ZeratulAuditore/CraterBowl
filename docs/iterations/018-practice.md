# 018: Offline practice mode (A17)

## Goal
Solo practice offline: focused drills for core skills, plus a no-pressure scrimmage vs bots.

## How Gridiron does it
"Offline practice mode" alongside online matches.

## Design
`src/sim/drills.gd` (pure). Each drill builds **only the athletes it needs** into a fresh World (no "inactive athlete" flags threading through the sim), picks your athlete, scores reps from World events, and resets reps:
- **Passing:** you're the QB with WR, WR, RB, no defense. Each rep cycles the playbook. Catch = success; incomplete = miss.
- **Catching:** you're the left WR; an AI QB throws to you; one AI CB plays man coverage. Catch = success; anything else = miss.
- **Tackling:** you're the LB; an AI RB starts live with the ball 12 yd away and runs at the end zone. Tackle = success; TD/OOB/6 s timeout = miss.
- **Scrimmage:** full 7v7 vs bots, no game clock, normal downs.

Reps: whistle/result → 1.2 s pause → reset at the drill LOS. Stats: reps, successes, streak, best streak.
World gains `start_live_with(id)` (live play with a given carrier, no snap) for the tackling drill.
Main: `-- --practice=passing|catching|tackling|scrimmage`; practice never runs the game clock; the HUD shows drill stats.

## Better than Gridiron
Drills isolate one skill with instant reps and streak tracking. That's faster learning than full scrimmages.

## Acceptance criteria
- Each drill builds the right athletes and your role (passing: you = QB, 4 athletes; catching: you = WR + QB + CB; tackling: you = LB vs RB; scrimmage: 14).
- Passing: catch → success+1, streak+1; incomplete → miss, streak 0; reset → PRESNAP at the drill LOS with the next play.
- Tackling: the rep starts LIVE with the RB carrying; tackle → success; timeout → miss.
- Catching: the AI QB throws to you within 4 s of the snap.
- Flow: passing drill completion counted via the real game; tackling drill tackle via the real E key.
