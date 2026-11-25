# 001: Field + player (A01)

## Goal
A regulation field with end zones and one third-person player who can run and sprint (sprint costs stamina), with a follow camera.

## How Gridiron does it (genre mechanic)
Third-person, one athlete per person, sprint to the end zone. Sprint is the core movement skill.

## Options
1. **Physics-body movement (CharacterBody3D only).** Quick to write, but rules live in nodes and are hard to unit test or run server-side.
2. **Pure sim + thin node.** `PlayerMotion` (RefCounted) owns position, velocity and stamina. The node feeds it input and mirrors the position. **Picked.** It's deterministic, testable, and ready for server authority (A10).
3. Root motion from animations. Overkill before there's any art.

## Better than Gridiron
**Exhaustion lockout:** draining stamina to 0 locks sprint until it recovers to 25%. This makes sprint a decision, not a held button. Acceleration curves make cuts readable, and they're tunable in `tuning.gd`.

## Units
Sim uses **yards** on a 2D plane: x = across the field (0..53.33), y = down the field (-10..110). Goal lines at 0 and 100, end zones beyond. One render unit = one yard.

## Acceptance criteria
- Field reports goal lines at 0/100, end zones 10 yd deep, width 53.33; point classification works (in bounds, in end zone A/B).
- From rest, holding run reaches run speed (±0.1) within 1 s; sprint reaches sprint speed, which is faster than run speed.
- Sprinting drains stamina; when it hits 0, speed caps at run speed until stamina ≥ 0.25 (lockout).
- Not sprinting regenerates stamina, capped at 1.
- Releasing input decelerates to ~0 within 1 s.
- Player position is clamped to the playable area (field + end zones + 2 yd margin).
- Diagonal input is not faster than straight input.
- Main scene boots headless with a field, player and camera and no errors.
