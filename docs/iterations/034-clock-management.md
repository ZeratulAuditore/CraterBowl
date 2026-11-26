# 034 — Running clock and timeouts

Make the time between snaps matter and give both teams a way to stop the clock. Gridiron used a one-minute warning and team timeouts (O, cited in C04a).

- Running the clock through every dead ball is simple, but it removes the value of reaching the sideline.
- Running after in-bounds tackles rewards clock management. The match already knows whether the result was a first down or a change of possession, so it can stop the clock at those breaks.
- A separate timeout phase would coordinate a long pause but add another state to every client. Use the existing dead-ball phases, reset the play clock during a timeout and keep the countdown to the next snap visible.

Show both teams' remaining timeouts on the scorebug throughout play. The host decides clock transitions, and clients receive the clock and timeout counts in snapshots.

## Acceptance

- After a short in-bounds tackle, the clock runs in the dead-ball delay and before the next snap. Incompletions, sideline stops, first downs, scores and changes of possession stop it.
- The one-minute warning occurs once per half. A live play finishes before the warning stops the clock. A crossing between plays stops the clock at 1:00.
- A half can expire between plays without another snap. A pending live play and the resulting try can still finish.
- An athlete on either team can use U between plays to spend one timeout and stop the game clock. Live and exhausted requests are rejected. Each team gets three per half, or two in 3v3. Halftime resets both counts.
- The normal input handler, host snapshot and timeout banner agree on the count. Both teams' timeout pips stay visible during live play.
