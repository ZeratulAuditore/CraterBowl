extends RefCounted
## All gameplay feel numbers. Units: yards, seconds.

# Movement
const RUN_SPEED := 7.0
const SPRINT_SPEED := 9.5
const ACCEL := 20.0          # yd/s^2 toward target velocity
const DECEL := 24.0          # yd/s^2 when no input

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
