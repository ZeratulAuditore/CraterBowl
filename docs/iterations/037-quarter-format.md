Issue: #4

# 037 Four-quarter format

Private hosts can select four short quarters. Gridiron offered configurable quarter lengths, and the remaster displayed a quarter clock. The documented default remains two halves.

- Reusing halftime at each quarter boundary would reset the drive and give teams extra timeouts.
- Splitting the clock display alone would skip a real break after Q1 and Q3.
- Keep the half for rules and track the quarter separately. At the first boundary of each half, reset the clock and keep the next play intact. Reuse the existing break and kickoff after Q2.

The host can switch formats with Q and cycle lengths with H in the lobby. Both sides see the selected format and duration before committing to ready up.

## Acceptance

- A host can select four one-, two-, or three-minute quarters. New lobbies and previous lobby and snapshot payloads default to halves.
- Q1 and Q3 advance after the live play and any try finish. Possession, spot, down and timeouts carry over.
- Q2 ends with the halftime kickoff to the team that did not receive the opening kickoff. Timeouts reset then. Q4 can end between snaps. The one-minute warning occurs once per half.
- Both sides see the host's lobby settings and authoritative quarter clock. The real lobby keys select the format and length, and the scorebug shows the current quarter and time remaining.
