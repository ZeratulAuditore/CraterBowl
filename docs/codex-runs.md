## 2026-11-25

- Landed C08a defensive playbook (`153552b`) and C08b defensive play selection and synchronization (`9ed6fee`).
- 204 unit tests and full headless smoke passed. With multiple checkouts active, the first smoke run detected a change to shared settings. Subsequent checks used isolated user data, including a full rerun after the graphics merge.
- C08c and B03 remain open for assignments, bot behavior, play art, and the huddle. No items were skipped or stashed.

## 2026-11-25 — Defensive gameplay and huddle

- Landed C08c and B03 together (`8e823de`). Verified 208 unit tests, full headless smoke including remote recall, and offscreen captures for both teams.
- The first final smoke attempt hit a fixed matchmaker port conflict. The retry passed with isolated user data. B09 and C02 were already claimed by the kicking-game branch.
