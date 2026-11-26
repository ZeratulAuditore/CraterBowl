Issue: #52

# 039 Roster rejection tests

Online players keep their host-assigned athletes during a match. Team and position selection are common in the genre, and Crater Bowl tracks its own selection flow in #18. This iteration makes the current assignment rules testable.

- Routing the legacy commands into new production handlers would add an online position-selection API ahead of #18.
- Checking assignment only in the network test observes the final result. The same result can come from an unsupported command or a rejected roster change.
- Keep the network check and assert the protocol and roster decisions directly. This produces a failure that identifies which rule changed and verifies that a rejected pick preserves both players' assignments.

## Acceptance

- The match protocol rejects client requests to change team or claim a slot.
- If a player tries to claim an occupied slot directly in the roster, both existing assignments stay intact. A claim succeeds when the slot is freed.
- After a connected client sends the two legacy requests, its host-assigned athlete and team remain the same.
- Planting a failure in the protocol or the occupied-slot rule makes the relevant unit check fail.
