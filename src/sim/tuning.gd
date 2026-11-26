extends RefCounted
## All gameplay feel numbers. Units: yards, seconds.

# Movement
const RUN_SPEED := 7.0
const SPRINT_SPEED := 9.5
const DECEL := 24.0          # slide deceleration after a tackle dive
const BLOCK_SPEED := 2.8
const DASH_SPEED := 13.0
const SPIN_SPEED := 7.5
const DASH_TIME := 0.22
const SPIN_TIME := 0.32
const MOVE_CHARGE_PER_YARD := 0.05

# Stamina (0..1)
const STAMINA_DRAIN := 0.25  # per second while sprinting
const STAMINA_REGEN := 0.15  # per second while not sprinting
const STAMINA_LOCKOUT_RECOVER := 0.25

# Field (regulation)
const FIELD_LENGTH := 100.0
const FIELD_WIDTH := 53.33
const ENDZONE_DEPTH := 10.0
const OOB_MARGIN := 2.0

# Ball
const SNAP_TIME := 0.35        # seconds for snap flight C -> QB
const BALL_CARRY_HEIGHT := 1.1 # yards above turf when held

# Passing
const GRAVITY := 10.73          # yd/s^2
const RELEASE_HEIGHT := 2.0
const CATCH_HEIGHT := 1.1
const THROW_SPEED_MIN := 12.0
const THROW_SPEED_MAX := 30.0
const THROW_INHERIT := 0.3      # fraction of thrower velocity added to ball
const PLAYER_PASS_POWER := 0.68

# Catching
const CATCH_RADIUS := 1.2
const CATCH_MIN_HEIGHT := 0.3
const CATCH_MAX_HEIGHT := 2.6
const CONTEST_MARGIN := 0.35
const MIN_PASS_TRAVEL := 2.5      # ball must travel this far before it can be caught/deflected
const INT_RADIUS := 0.6           # defender must be this close to the ball to intercept

# Tackling
const DIVE_SPEED := 11.0
const DIVE_TIME := 0.35
const TACKLE_REACH := 1.0
const DIVE_RECOVER := 1.0

# Placeholder AI
const AI_RUSH_DELAY := 2.5
const AI_DIVE_RANGE := 2.0

# Bodies + blocking
const BODY_RADIUS := 0.45
const ENGAGE_DIST := 1.0
const ENGAGE_FACING_DOT := 0.3
const BLOCK_DRIVE := 0.7       # fraction of defender displacement taken from blocker
const BLOCK_HOLD := 1.5
const BLOCK_IMMUNITY := 0.75
const BLOCKER_BEATEN := 1.5   # after a shed, the blocker cannot re-engage for this long

# AI QB
const AI_QB_THROW_TIME := 2.0
const AI_QB_PASS_POWER := 0.65
const AI_QB_DEPTH_WEIGHT := 0.2
const AI_QB_PRESSURE := 3.0

# Fumbles / loose ball
const FUMBLE_BEHIND_DOT := 0.5
const FUMBLE_KNOCKDOWN := 0.8
const LOOSE_FRICTION := 6.0       # yd/s^2 rolling deceleration
const LOOSE_BOUNCE := 0.35        # vertical restitution
const RECOVER_RADIUS := 0.8
const RECOVER_MAX_HEIGHT := 1.0

# Bots
const NEUTRAL_ZONE_HALF := 0.5     # pre-snap: each side stops this far from the LOS
const BARRIER_HEIGHT := 2.4        # LOS barrier wall height (m)
const BARRIER_REVEAL_DIST := 3.0   # barrier brightens near athletes within this (yd)
const BARRIER_DROP_TIME := 0.3     # barrier dissolve after the snap (s)
const AI_SNAP_DELAY := 2.5         # AI-only offense snaps after this long presnap
const AI_COVER_REACTION := 0.25   # defender reacts to where the receiver was
const AI_COVER_TRAIL := 0.8       # yards behind along the receiver's path
const AI_SPY_DEPTH := 6.0
const AI_DEEP_ZONE := 14.0
const AI_PROTECT_BALL_RANGE := 4.0 # don't sprint with a defender this close
const AI_SPY_BLITZ_TIME := 3.5     # QB still holding it: the spy attacks
const AI_QB_MIN_SEPARATION := 1.5
const AI_QB_MAX_HOLD := 3.2

# Chaosball
const CHAOS_GRAVITY_SCALE := 0.45
const CHAOS_MAX_BOUNCES := 3
const BOUNCE_RESTITUTION := 0.55
const BOUNCE_FRICTION := 0.8
const AI_CHAOS_PRESSURE := 3.5
const LOB_ANGLE := 65.0           # degrees, touch-pass arc
const PASS_CLOCK := 5.0              # Chaosball: ball explodes if held this long
const STREAK_BASE_POINTS := 2
const STREAK_MAX_POINTS := 7
const AI_PASS_CLOCK_MARGIN := 1.2

# Defensive play suggestions
const DEFENSE_GOAL_LINE_RANGE := 5.0
const DEFENSE_PREVENT_DISTANCE := 15.0
const DEFENSE_PREVENT_TIME := 60.0
const DEFENSE_UNDER_DEPTH := 8.0
const DEFENSE_DEEP_DEPTH := 18.0
const DEFENSE_PREVENT_DEPTH := 25.0
const DEFENSE_GOAL_DEPTH := 4.0
const HUDDLE_SECONDS := 5.0
const PROTECTION_RANGE := 8.0
