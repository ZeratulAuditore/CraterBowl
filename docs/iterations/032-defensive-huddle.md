# 032 — Defensive assignments and play calling

Give both teams an opening play-call view and make defensive calls change bot movement. Gridiron uses a presnap coverage selector and field art to coordinate assignments.

Use the existing match clock and action channel for a compact five-second call view, with a single key to cycle the highlighted call. A separate timed match phase would synchronize an extra state across clients and would slow down quick practice snaps. A full-screen playbook would obscure the live field. Keep the assignments on the field and highlight the local athlete's assignment so it can be read from the normal camera.

## Acceptance

- Man calls preserve receiver tracking. Zone defenders hold distinct landmarks and break on throws. Blitz calls send an extra defender after the QB.
- The defending team can choose calls through the normal input handler and sees its assignments during presnap. Opposing assignments stay hidden.
- Both teams see their current call and alternatives in the opening five seconds of presnap.
- Cover 2 reduces deep completions per snap across 24 matched bot plays against legacy coverage.
- Each side can recall its previous call. Offense can mirror the wide receiver assignments. Players can opt into the default call and skip the huddle display.
- The defining assignment art includes underneath and deep zones, man matchups, rush lanes, receiver routes and protection targets.
