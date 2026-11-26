Issue: #98 (part of #8)

# 041 Forward-progress spotting

**Goal.** A carrier who is met and driven backward before the tackle keeps the yards he had
reached. Before this, the ball was spotted wherever the carrier stood at the whistle, so a
linebacker who leaned on a runner for half a second before diving took two or three yards off him.

**Genre.** Football games spot the ball at the carrier's forward progress: where his momentum
toward the goal was stopped, not where a pile pushed him to. Arcade titles usually do it implicitly
by whistling the play on first contact.

## Options

1. **Whistle on first contact.** Simple and never wrong about spotting, but it kills the contact
   game (spins, breaking a lean, carrying a defender) and the dive-to-tackle feel.
2. **Max forward point while in contact.** Track the furthest point reached during a contact
   window and spot there. Over-credits a QB who drifts back on his own with a rusher on him: he'd
   get the yards back on a sack.
3. **Max forward point, capped by how far opponents' bodies pushed him back (pick).** The window
   records both the furthest point and the net push the collision resolver applied to the carrier
   from opponents. The spot is `min(furthest, current + pushed)`, never behind the carrier. Being
   driven back is credited; retreating voluntarily is not.

**Pick: 3.** It is as cheap as 2 (two floats per frame), deterministic, and sacks stay honest.

**Better than the genre:** the HUD names the call ("FORWARD PROGRESS +2.7 YD") when it gives back
half a yard or more, so the player sees why the ball is ahead of where they went down.

## Rules (src/sim/world.gd)

- Contact = an opponent within `T.CONTACT_REACH` (1.0 yd, the tackle reach) of the carrier.
- The window opens on contact, stays open `T.FORWARD_PROGRESS_GRACE` (0.3 s) after contact
  breaks, and resets on a new carrier or a new snap.
- Attack direction: the world offense (also the kicking team) attacks +y, everyone else -y, so
  returns after picks, fumbles and kicks mirror correctly.
- Applies to tackle whistles only (also a carrier's own dive). Out of bounds and touchdowns are
  unchanged. The dead carrier is placed at the spot (the dead ball stays attached to him).
- The tackle event carries `progress` (yards credited) for the HUD.

## Acceptance

- A defender drives a stationary carrier back more than a yard and then tackles him: the spot is
  within 0.15 yd of where contact began (`test_driven_back_carrier_spotted_at_forward_progress`).
- A carrier retreating on his own while touching a rusher is spotted where he is
  (`test_retreating_in_contact_is_not_credited`).
- After contact breaks for longer than the grace, the old contact point is no longer credited
  (`test_progress_window_resets_after_contact_breaks`).
- A defensive carrier (attacking -y) driven toward +y is spotted at his furthest -y progress
  (`test_return_team_forward_progress_mirrors`).
- Same inputs give the same spot (`test_forward_progress_is_deterministic`).
- In the real scene, Space snaps, the LB drives the QB back 2+ yd, the dive is whistled, the
  overlay shows FORWARD PROGRESS and the next snap lines up at the forward-progress spot
  (`tests/game_flow.gd` window 13400-13480, `tests/visual/forward_progress_test.gd`).

## Didn't work

- Driving the LB by moving it a fixed 0.15 yd per frame in the rendered test let it pass through
  the QB on the software-GL path (the QB gave ground only 0.44 yd). Placing the LB at a fixed
  0.75 yd overlap each frame is robust and is what both scripted tests do.

## Left for other children of #8

- #99 fumble variety (hit speed / tackle from behind for fresh carriers).
- #100 INT and fumble return yards in stats.
