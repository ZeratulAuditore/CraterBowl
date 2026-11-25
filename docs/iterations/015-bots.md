# 015: Bots (A14)

## Goal
AI fills every empty slot on both sides well enough that 1v1, 2v2 or solo matches play like real football.

## How Gridiron does it
Online 7v7 with private/practice modes; empty slots need bodies.

## Gaps found before designing (from reading ai.gd)
- An AI receiver who caught the ball **stood still** (the held-ball branch only handled the QB).
- An AI **returner stood still** after a takeaway (`_escort` returned nothing for the carrier).
- No coverage: defenders idled for 2.5 s, then everyone chased the QB.
- An AI offense never called plays and only snapped via the 20 s play clock.

## Design (`src/sim/ai.gd`)
- **Ball carrier:** head for the scoring end zone, juke laterally around defenders in a 5-yd lane, stay in bounds, and **don't sprint with a defender within 3 yd behind** (respects the A13 fumble rule).
- **Man coverage:** at the snap each eligible receiver gets the nearest free CB/S (LBs only take backs). Defenders trail with a 1.5-yd cushion. Unassigned safeties sit in a deep zone; the LB spies the QB 6 yd off and blitzes at 3.5 s or if the QB crosses the LOS.
- **Ball in the air:** the 2 nearest per side (eligible receivers / defenders) break to the predicted landing point; the rest hold coverage.
- **QB:** drifts away from the nearest rusher inside the pocket, and throws per the A07 rule.
- **Presnap:** an AI-run QB calls a situational play (long → Deep Shot/Verticals, short → Slants, 3rd → Flood…). An offense with no humans snaps after 2.5 s.

## Better than Gridiron
Bots respect the same skill rules as humans (no-sprint ball security), so they're readable teachers for new players.

## Acceptance criteria
- An AI catcher with open field gains ≥ 10 yd in 2 s.
- An AI carrier doesn't sprint with a defender close behind.
- A man defender stays within 4 yd of his WR through a 2-s route.
- With a ball in the air, the nearest defender moves toward the landing point.
- choose_play: 3rd & 15 → deep; 2nd & 2 → Slants.
- An all-AI offense calls a play and snaps within 3 s of presnap.
- **Bot game:** 4 min of game time, all bots, no humans → ≥ 8 plays complete, no play lasts > 25 s, and the downs/score advance.
