# Live join capability lifecycle — M16.15

## Scope and current authorization

M16.9–M16.12 Team breakouts are now **ENABLED** by the consolidated Team Portal
product decision. Breakout requests additionally require current membership of
the exact Team, or current assigned Cohort Master authority for media only.
Team removal denies future breakout tokens and Team Portal access. Team removal
alone is not revocation of an otherwise current Cohort enrollment.

`getLiveSessionJoinToken({liveSessionRoomId})` accepts only the canonical room
ID. Identity, display name, role and provider reference are server-derived.
Every new request checks current account and exact Cohort/session authority,
including a check after provider issuance. Students reuse M16.4 eligibility;
Masters retain existing scoped authority. Inactive accounts or withdrawn/
removed enrollments cannot obtain new Cohort tokens. Known IDs, old tokens and
client user/Team/role claims cannot restore authority.

## Already-issued tokens

The existing server-controlled lifetime is **60 seconds** from issuance in Unix
seconds. Daily receives one `room_name`, canonical `user_id`, `is_owner: false`
and, since M16.8, `eject_at_token_exp: true`.

FICI revocation denies new issuance; it does **not instantly revoke** an already
delivered provider token. Before its original expiry, that token may remain
usable even after FICI account/enrollment authorization is lost. Under Daily's
private-room contract, expiry blocks reuse and the ejection flag ends an
existing participant's access. The accepted configuration therefore also
bounds a joined call by the original expiry. Continuing requires a fresh
authorized join; no automatic renewal or provider revocation infrastructure
is implemented.

Source: [Daily meeting-token lifecycle](https://docs.daily.co/reference/rest-api/meeting-tokens),
reviewed 2026-11-11.

## Persistence and validation limits

Tokens are temporary transport data, never canonical user, Activity or Project
data. Existing responses are private/no-store; the UI uses the capability only
for the intended Daily frame. Authorization RPCs receive no token and issuance
does not persist it.

M16.15 runs the actual FICI service/adapter pipeline with mocked authorization
RPCs and Daily HTTP, fake-clock expiry checks, and outbound expiry/ejection
claim assertions. Provider expiry/ejection is a documented contract, not a live
Daily media experiment. Accepted M16.4/M16.5 database removal/isolation results
are retained. No production, schema, authorization or breakout behavior changes.
