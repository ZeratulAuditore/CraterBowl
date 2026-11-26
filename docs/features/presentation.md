# Match presentation

The compact match scorebug groups the teams, score, possession diamond, remaining
timeouts, current period and game time, play clock, down and distance, field spot,
and match mode. The period label follows match rules. Classic matches currently
use halves. Kickoffs and conversion attempts get their own state labels.

The field spot names the team whose territory contains the ball. The mini field
reads from the offense's end toward the goal it attacks. The cyan marker is the
line of scrimmage and the gold marker is the line to gain. The mini field appears
in Classic scrimmage states with a line to gain.

The rendered integration test captures scrimmage, kickoff, and conversion states.
Run it with `./scripts/visual_test.sh`.
