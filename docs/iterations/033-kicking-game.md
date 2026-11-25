# 033: B09 + C02 Kicking game (coin toss, live kickoffs, punts, field goals, PATs)

## Goal
Make the kicking game real. A coin toss decides who kicks first. Kickoffs and punts are live plays with returns, field goals and PATs are kicked through actual uprights, and kicks can be blocked. Before this, every kickoff was an instant "ball at the 25", 4th down was always go-for-it, and the 1-point try was a run from the 3.

How the genre does it: a power meter plus aim, a punt or field goal called on 4th down, live returns, touchbacks, and blocked kicks that become a live ball (scoop and score).

## Options
1. **Automatic kicks.** Pick an outcome from distance plus a random roll. Cheap, but there's no skill and nothing to watch.
2. **Separate kick minigame UI** (a swinging needle). Adds a new input mode and new UI for every kick type.
3. **Reuse the throw meter (picked).** Hold J or the left mouse button to aim and charge; release to kick. The launch angle is fixed per kick type: punt 52°, field goal/PAT 38°, kickoff 42°. Speed comes from the meter. The kick is fully deterministic: no wobble, so the skill is the aim plus the power. It adds no new controls besides **K**, which cycles the kick call (none → punt → field goal). The ball flies through the real sim, so blocks, catches, bounces and touchbacks are physics, not dice.

**Better than the reference:** the arc preview shows the kick's flight before release, so a field goal is readable rather than a guess. Onside kicks also fall out of the physics: a kickoff the kicking team recovers after it travels 10+ yd stays with them.

## Rules (sim)
- **Coin toss:** `Match.start_match(seed, winner_has_humans)`. The winner has 5 s to choose 1 = receive or 2 = kick. If they don't choose, or the winner is all bots, they receive. The kickoff is locked until the choice is made. The other team receives the 2nd half.
- **Kickoff:** from the kicking team's own 35 (the 20 after a safety), with the returner at his own 10. Space or the play clock kicks at a default power; the meter kicks with aim. Results:
  - A ball fielded in the air or on the ground is a live return.
  - Fielded in the end zone, or landing in or beyond it: touchback at the 25.
  - Out of bounds: receiving team at its 40.
  - Rolled dead or downed by the kicking team: ball at that spot.
  - Recovered by the kicking team after 10+ yd: onside.
- **Punt:** on any scrimmage down, the punter sets up 10 yd deep and a returner drops back. Results:
  - Return: ball where the returner is tackled.
  - Touchback: the 20.
  - Downed or rolled dead: ball at that spot.
  - Fake punt: a run or pass plays normal downs.
- **Field goal / PAT:** the holder sets up 7 yd deep. The kick is good if it crosses the end line between the uprights (span from the field width, matching the art) above the 3.3 yd crossbar. A miss gives the defense the ball at the spot of the kick, or at its own 20 if the spot is inside that.
- **Tries:** 1 = PAT kick snapped from the 15; 2 = scrimmage from the 10.
- **Blocks:** a rusher within 1 yd of the ball in its first 5 yd of travel (below 3 yd high) blocks it. The ball pops up loose and live: scoop and score, or the kicking team recovers and normal downs apply (4th and short → turnover on downs).
- **Chaosball** keeps its instant possession changes (no kicks).
- **Bots:** on 4th down they attempt a field goal when it's within 50 yd, go for it on 4th and 2 or shorter past midfield, and punt otherwise. They kick PATs. Bot kickoffs vary in depth and direction. On a kick in the air, the coverage sprints in lanes, the returner settles under the ball, and the rest of the return team forms a wall.

## Acceptance
- Toss: deterministic winner; the choice changes who kicks; the window times out to receive; bots receive immediately; the 2nd half flips.
- Kickoff alignment; return tackled → ball at the spot; touchback at 25; end-zone fielding = touchback; out of bounds → 40; onside recovery; return TD → try for the returners.
- Punt alignment and the call; landed and downed at the spot; touchback at 20; return tackled at the spot; fake punt plays downs.
- FG good +3 then a kickoff; wide → defense at its 20; short → spot of the kick; under the crossbar = no good; PAT good / no good; the 2-pt choice is scrimmage.
- Blocked FG is loose → scoop and score; blocked punt recovered short → turnover on downs.
- Bots: 4th-down rule, bot punts, bot FG good, a full bot match with kicks finishes with a sane score.
- Network: kick, kick_call and toss actions are sanitized and routed; snapshots carry the kick call, kicked flag and toss winner.
- Real game (game_flow): toss → 2 key → kickoff with the meter (HUD + arc) → return; K → punt → possession changes; K K → field goal good with the meter → +3 → kickoff.
