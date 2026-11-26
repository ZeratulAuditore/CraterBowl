# 033 — Handoffs and designed runs

Give quarterbacks and backs a live exchange and give linemen distinct run assignments. Gridiron uses a proximity handoff and a re-handoff cooldown (O, cited in C01).

- An automatic exchange on a run call frees a button but removes the human QB's timing choice.
- A timed meter makes the exchange its own skill check and adds a second timing task to a quick snap.
- Use a single proximity action. Show the QB when the back is in range and draw the back's path and the linemen's targets before the snap. Inside Zone and Outside Sweep offer a choice about where to attack, and the existing flip action can change sides. These assignments make a called run readable from the huddle through the exchange.

## Acceptance

- In a classic play with an RB, the offense QB can hand off behind the line during live possession. The back must be within reach and available to take the ball. Repeated exchanges are rate-limited and rejected during the cooldown.
- Inside Zone attacks an interior gap and Outside Sweep takes a wider path. Flip mirrors the lane. Assigned bot linemen lead the run and engage defenders. Run calls are omitted in formats without an RB.
- The RB can advance through the line while the play stays live. A whistle records one carry and yards for the RB. A fumble records the carry at the fumble spot.
- A deterministic two-minute classic bot match finishes with a bounded score and records both handoffs and throws.
- The normal handoff key works in the scene. The host validates the actor and synchronizes the exchange to the client. Both sides see the correct holder without changing online roster assignments.
