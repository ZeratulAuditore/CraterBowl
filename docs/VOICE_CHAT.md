# Team voice chat — plan

Status: **planned** (2026-11-25). Nothing implemented yet.

## Goal

In an online match, each human hears **only their own teammates** and can talk to
them while playing. Play calls stay secret from the other team. No third-party
service, no account, no extra install. It works over the ENet session we
already have.

Out of scope (v1): text chat, cross-team voice during a match, spectator voice,
recording voice into replays, voice in offline/bot-only games.

## How it fits the current netcode

- `NetSession` is a listen server. The host is peer 1 and also plays. Every
  client already talks only to the host, and `_on_packet` routes on `msg.k`.
- A peer's team is `world.athletes[peer_athlete[peer_id]].team`. Lobby peers
  (`lobby.players`) have no athlete yet, so they have no team.
- Voice therefore goes **client → host → same-team clients**. The host decides
  who receives each packet, so a client can never subscribe to the other
  team's audio. (A modified *host* could still listen in. We accept that
  because it's a friends game, and the host already sees all game state.)

```
 mic ─► capture bus ─► resample 16 kHz ─► 20 ms frames ─► encode ─► "vc" packet (ENet ch 2, unreliable)
                                                                         │
                                         host: VoiceRouter.recipients(sender)  (same team, not muted-by-server)
                                                                         │
 speaker ◄─ AudioStreamGenerator ◄─ jitter buffer ◄─ decode ◄────────────┘   (one per remote speaker)
```

## Design decisions

| Topic | Decision | Why |
|---|---|---|
| Who hears whom | In a match: your team only. Pregame lobby and post-game: everyone. | Protects play calling, while still allowing hellos and "gg" before and after. |
| Topology | Relay through the host, no P2P mesh | Reuses the existing connections and NAT/UPnP setup. The host enforces team isolation. |
| Default transmit mode | Push-to-talk on **T** (rebindable; `V` is taken by replay). Open mic with a voice-activity threshold is an option. | Godot has no echo cancellation, so open mic plus speakers would feed game audio back. |
| Codec, v1 | IMA-ADPCM in pure GDScript, mono 16 kHz, 4 bits/sample ≈ 64 kbps | No native dependency, testable headless, deterministic. |
| Codec, v2 | Opus through the `twovoip` GDExtension (≈ 16–24 kbps) behind the same `VoiceCodec` interface | Do this only if host upload bandwidth becomes a problem (see below). |
| Framing | 20 ms frames, 2 frames per packet (40 ms, 25 pkt/s), `seq` per speaker | Balances overhead and latency. |
| Transport | `{"k":"vc","s":seq,"d":PackedByteArray}` from the client. The host adds `"p":speaker_peer`. Unreliable on **ENet channel 2**. | Keeps voice from delaying snapshots (ch 1) or reliable events (ch 0). |
| Playback | One `AudioStreamPlayer` + `AudioStreamGenerator` per remote speaker. 60 ms jitter buffer. On packet loss, repeat the last frame faded, then go silent. | Standard VoIP approach. Latency budget is about 150 ms. |
| Abuse limits | The host drops packets over 1 KB and anything over ~12 KB/s per peer. Seq must increase. | Matches the existing `sanitize_input` style. |

### Bandwidth (worst realistic case: 7v7, host plus 13 remote humans)

Assume about 2 people talking at once per team. That's 4 speakers, each relayed
to up to 6 teammates, at ~70 kbps with headers.

- **ADPCM:** ~1.7 Mbps of host upload. Fine on most broadband, tight on weak
  uplinks.
- **Opus:** ~0.5 Mbps.
- **Clients:** at most ~0.4 Mbps down, even with ADPCM.

Ship ADPCM first, measure, and switch to Opus only if a host struggles.

## Components

| File | New/changed | Responsibility |
|---|---|---|
| `src/net/voice_codec.gd` | new | Pure static `encode(PackedFloat32Array) -> PackedByteArray` / `decode`. Holds the ADPCM state per stream. |
| `src/net/voice_jitter.gd` | new | Pure jitter buffer: `push(seq, frames)`, `pop() -> frame or PLC`. Handles reordering, duplicates, and gaps. |
| `src/net/voice_router.gd` | new | Pure `recipients(sender, peer_athlete, athletes, phase) -> Array[int]`. Team-only in a match, everyone in lobby/post-game, never echoes back to the sender. |
| `src/net/net_session.gd` | changed | `send_voice(seq, bytes)`; a `"vc"` case in `_on_packet`, where the host validates, rate-limits, and forwards per the router and the client emits `voice_received(peer, seq, bytes)`. The host's own mic goes through the router directly with no network hop. |
| `src/game/voice.gd` | new | Node owned by `main.gd` in online modes. Mic capture (`AudioStreamMicrophone` → `Mic` bus with `AudioEffectCapture`), resampling, PTT/VAD gate, encoding/sending, and per-speaker decoders and players. Exposes `speaking(peer) -> bool`. |
| `default_bus_layout.tres` | new | Buses: `Master`, `Music`, `Voice` (incoming), `Mic` (muted, capture effect). |
| `project.godot` | changed | `audio/driver/enable_input=true`. |
| `export_presets.cfg` | changed | macOS microphone usage description and audio-input entitlement. |
| `src/ui/controls.gd` | changed | `["talk", "Push to talk", KEY_T]`. Pad: hold the left bumper. |
| `src/ui/settings_store.gd` | changed | `voice_enabled` (default on), `voice_mode` (`ptt` / `open`), `voice_volume`, `mic_gain`, `mic_device`, `vad_threshold`. |
| Settings → Audio (main menu) | changed | Voice on/off, mode, volumes, input device picker (`AudioServer.get_input_device_list()`), and a **mic test meter**. |
| `src/game/overlay.gd` | changed | Mic icon while you transmit. Teammate name list with a speaking pulse. Speaker icon above the head of a teammate who is talking. |
| Scoreboard (Tab) | changed | Per-player mute toggle, local only and per match. Muted peers' packets are dropped before decoding. |
| `lobby_stage.gd` / post-game | changed | Speaking indicators on lobby player cards. |

## Milestones

1. **Pure core + tests.** Build codec, jitter buffer, and router, plus
   `tests/test_voice_codec.gd` (round-trip SNR above a threshold, odd frame
   sizes), `test_voice_jitter.gd` (reorder, loss, duplicates, late packets),
   and `test_voice_router.gd` (same-team only, lobby = all, no self-echo,
   recipients update after `set_assignment` swaps a team, disconnected peers
   dropped). All headless.
2. **Wire it.** Add the `"vc"` relay in `NetSession`, the `voice.gd` node, PTT,
   and the bus layout. Add a `--voice-test-wav <file>` CLI arg that feeds a WAV
   in place of the mic, so `tests/net_client.gd`-style two-instance runs can
   assert that a teammate receives frames and an opponent receives none.
3. **UX.** Settings section with the mic meter and device picker, HUD/lobby
   speaking indicators, scoreboard mute, and the macOS permission prompt.
   Manual playtest with 4 people over the internet.
4. **Polish.** Open-mic VAD with hangover (~300 ms), auto-duck music while
   teammates talk, and the Opus codec if bandwidth measurements call for it.

**Done when:** in a 3v3 internet match, teammates hear each other at about
≤200 ms mouth-to-ear with no audible gaps at 2% packet loss. A packet capture
shows zero voice packets reaching the opposing team's clients.

## Risks

- **GDScript performance:** ADPCM is about 16k samples/s per stream. Encoding 1
  stream and decoding up to 6 should cost well under 1 ms per frame. Benchmark
  this in milestone 1, and drop to Opus if it doesn't hold.
- **Mic resampling:** the mix rate is 44.1 or 48 kHz depending on the OS. Use
  linear resampling with a simple low-pass. That's good enough for speech.
- **Echo/feedback with open mic:** there's no AEC in Godot. Keep PTT as the
  default and show a "use headphones" hint when open mic is selected.
- **WSL dev box:** mic input under WSLg is unreliable, so use the WAV injection
  path for local testing.

## Open questions

1. Should the pregame lobby and post-game be all-chat (as planned), or
   team-only everywhere?
2. Should push-to-talk be the default, or open mic?
3. Is a native GDExtension (Opus) acceptable later, or should we stay pure
   GDScript forever?
