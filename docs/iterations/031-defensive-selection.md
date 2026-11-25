# 031 — Defensive play selection

Give the match an authoritative defensive call for each snap. Gridiron lets the defending team pick its own coverage before the snap.

A client-only selection would be fast to display but could disagree across teammates. A reliable call event would need separate handling for late joiners. Store the call in the sim and reuse match snapshots so late joiners see the current selection immediately. Preselect the situational recommendation on the server so the defense can accept it without an extra action once the huddle is wired up.

## Acceptance

- A classic match starts each new formation with the situational call. Chaosball has no defensive call.
- The server accepts known defensive calls from defenders during presnap and rejects offense, unknown calls and live changes.
- A remote defender's selection returns through the host snapshot codec.

Player controls, assignment behavior and art follow in C08c.
