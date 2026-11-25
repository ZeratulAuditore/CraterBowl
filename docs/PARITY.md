# Gridiron parity audit (A28)

Source of truth for "does our game match Gridiron's features" (Steam 708720 / Gridiron Remastered 3878710, researched 2026-11-24). Mechanics and modes only. Name, art, UI and audio are original.

`./scripts/parity_audit.sh` runs every suite and checks each evidence line below against the real test logs. A feature passes only if **all** its evidence passed. `PENDING` = owned by a parallel session; `GAP` = missing, tracked in FEATURES.md "Discovered".

| ID | Gridiron feature | Where | Status |
|---|---|---|---|
| G01 | 7v7 online American football, one athlete per player | roster.gd, net_session.gd | auto |
| G02 | Custom matches 3v3 / 5v5 / 7v7 | match_config.gd | auto |
| G03 | Third-person control of your athlete | main.gd follow camera, player.gd | auto |
| G04 | Precision physics-based passing | passing.gd, world.throw | auto |
| G05 | Strategic routes + real-time coordination | routes.gd, route art, F/Q keys | auto |
| G06 | Snap, block, pass, tackle, sprint | world.gd, athlete.gd | auto |
| G07 | Casual + competitive matchmaking | matchmaker.gd, mm_server/client | auto |
| G08 | Private matches | lobby.gd, invite_code.gd | auto |
| G09 | Party up with friends (queue together) | — | GAP (D02) |
| G10 | Offline practice | drills.gd | auto |
| G11 | Chaosball 3v3: anyone throws/catches anytime | world rules | auto |
| G12 | Chaosball: up to 3 bounces off ground/walls | world rules | auto |
| G13 | Chaosball: catch your own pass | world rules + lob | auto |
| G14 | Chaosball: low gravity | world.gravity() | auto |
| G15 | Chaosball: pass streak raises TD value (cap 7) | world.streak_points | auto |
| G16 | Chaosball: pass clock explodes the ball | world._step_pass_clock | auto |
| G17 | Chaosball playable from matchmaking | — | GAP (D03) |
| G18 | Ranked climbing, seasons, season-exclusive rewards | ranked.gd | auto |
| G19 | Extensive stats system | stats.gd | auto |
| G20 | Public per-position leaderboards (top 100) | leaderboard.gd | auto |
| G21 | Cosmetics earnable through play, no gameplay effect; customization | cosmetics.gd | auto |
| G22 | Replays | replay.gd | auto |
| G23 | Achievements (Steam feature list) | — | GAP (D04) |
| G24 | Online co-op (humans together vs bots) | roster team swap + bots | auto |
| G25 | Easy-to-understand controls / menus / settings | A27 | PENDING (out-of-game session) |
| G26 | Sci-fi lunar stadium presentation | A26 | PENDING (graphics session) |

## Evidence
Format: `EVIDENCE <id> <unit|flow|net|mm> <pattern>`
```
EVIDENCE G01 unit test_roster.gd::test_builds_7v7
EVIDENCE G01 net joined by code into the private lobby
EVIDENCE G01 net own input moved own athlete on server
EVIDENCE G02 unit test_match_sizes.gd::test_configs
EVIDENCE G02 flow 3v3: 6 athletes + views
EVIDENCE G02 net client adopted host's 5v5
EVIDENCE G03 unit test_main_scene.gd::test_main_scene_loads
EVIDENCE G03 flow control switched to receiver
EVIDENCE G04 unit test_passing.gd::test_stationary_throw_hits_target
EVIDENCE G04 unit test_passing.gd::test_lead_target_hits_moving_receiver
EVIDENCE G04 flow pass thrown
EVIDENCE G05 unit test_routes.gd::test_ai_runs_slant
EVIDENCE G05 flow route lines drawn presnap
EVIDENCE G05 flow F key changes my route
EVIDENCE G05 flow Q key calls next play
EVIDENCE G06 unit test_ball_snap.gd::test_snap_transfers_to_qb
EVIDENCE G06 unit test_blocking.gd::test_ol_engages_and_slows_dl
EVIDENCE G06 unit test_tackling.gd::test_dive_tackles_carrier
EVIDENCE G06 unit test_player_motion.gd::test_sprint_faster_than_run
EVIDENCE G06 flow Space key snaps
EVIDENCE G07 unit test_matchmaker.gd::test_competitive_rating_window
EVIDENCE G07 mm MM TEST PASS (casual)
EVIDENCE G07 mm MM TEST PASS (competitive)
EVIDENCE G08 unit test_lobby.gd::test_lobby_ready_flow
EVIDENCE G08 net joined by code into the private lobby
EVIDENCE G10 unit test_drills.gd::test_builds
EVIDENCE G10 flow drill counted the completion
EVIDENCE G10 flow tackled with the real E key
EVIDENCE G11 unit test_chaosball.gd::test_throw_past_los_and_second_pass
EVIDENCE G11 unit test_chaosball.gd::test_opponent_catch_swings_possession
EVIDENCE G12 unit test_chaosball.gd::test_bounces_then_incomplete
EVIDENCE G12 unit test_chaosball.gd::test_catch_after_a_bounce
EVIDENCE G12 unit test_chaosball.gd::test_wall_bounce_keeps_ball_in
EVIDENCE G13 unit test_chaosball.gd::test_self_catch
EVIDENCE G14 unit test_chaosball.gd::test_low_gravity_still_hits_aim
EVIDENCE G15 unit test_chaos_scoring.gd::test_td_value
EVIDENCE G15 flow HUD shows streak + TD value
EVIDENCE G16 unit test_chaos_scoring.gd::test_pass_clock_explodes_and_turns_over
EVIDENCE G16 flow held too long: ball exploded
EVIDENCE G18 unit test_ranked.gd::test_season_rollover
EVIDENCE G18 unit test_ranked.gd::test_upset_gains_more
EVIDENCE G18 flow ratings saved
EVIDENCE G19 unit test_stats.gd::test_bot_game_consistency
EVIDENCE G19 flow stats tracked the completion
EVIDENCE G20 unit test_leaderboard.gd::test_top_sorted_and_capped
EVIDENCE G20 flow leaderboard file has You|QB at #1
EVIDENCE G21 unit test_cosmetics.gd::test_looks_never_touch_sim
EVIDENCE G21 flow your look shown on your athlete
EVIDENCE G21 net my equipped #88 round-tripped through the host
EVIDENCE G22 unit test_replay.gd::test_save_load_and_size
EVIDENCE G22 flow V starts instant replay
EVIDENCE G22 flow viewer opens the saved replay
EVIDENCE G24 unit test_roster.gd::test_swap_team_keeps_pairing
EVIDENCE G24 unit test_bots.gd::test_full_bot_game
```
