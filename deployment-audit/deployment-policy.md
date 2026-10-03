# Deployment policy and timeline

## AWS migration deployment policy

Applies to this user's web applications and hosted APIs. Native app releases
and unrelated hosting arrangements are outside this migration.

- Through **2026-10-22 07:00 UTC / 09:00 Europe/Amsterdam**, deploy releases to
  both Vercel and AWS from the same committed revision. Verify both deployments
  and record the revision, URLs and results. A Git push alone is not proof of
  a dual deployment. Keep production domains on Vercel during parallel testing.
- **2026-10-20**: readiness review. Verify functional parity, authentication,
  integrations, routes, background jobs, repeat deployment and rollback.
  Aim for at least two weeks of successful parallel operation per app. Report
  late or unverified apps as exceptions instead of shortening testing silently.
- **2026-10-22 07:00 UTC**: target AWS cutover. For a verified app, move production
  routing to AWS, verify its real domains, record the completed cutover, and
  disable Vercel Git auto-deployments, hooks and workflows. Thereafter deploy
  only to AWS. Do not invoke the old dual-deployment command after cutover.
- If readiness or cutover is incomplete at the cutoff, preserve the working
  production site, flag the exception and finish migration. A date alone never
  proves cutover happened. Do not silently resume Vercel-only releases or claim
  completion. Inspect the recorded state and live routing before deploying.
- **2026-10-23 07:00 UTC**: target Vercel cancellation review, only after all
  required apps are migrated and external service ownership is confirmed.
  Renewal is **2026-10-24 07:00 UTC / 09:00 Europe/Amsterdam**. These instructions
  do not schedule cancellation or authorize deleting projects or data.

Use the repository's verified deployment command. If AWS setup is missing,
implement and verify it as part of deployment work; do not invent a command or
report a Vercel-only release as complete. Keep a repository deployment record
with mode, commands, verified revision, URLs, checks and actual cutover time.
Preserve free databases and Squarespace domain registrations. Scheduled jobs,
webhooks, notifications, payments and schema migrations must have one active
owner to avoid duplicate effects.

Prefer a verified idle owned computer, then the current computer, over paid
build compute. Online does not imply idle. AWS serves the deployed websites
when build computers are offline.

This policy supersedes older Vercel-only deployment guidance. Include these
instructions in new clones/worktrees and ensure any agent performing a release
reads them. Working implementations and recorded verification, not this policy
alone, determine deployment readiness.

## Current implementation

As of 27 September 2026, three repositories provide verified AWS previews for
four Vercel project entries: 100apps.studio, How Many Executive Orders and the
two Fonsters deployments. Their migration implementations are merged into the
default branches. They provide `npm run deploy:parallel` with a cutoff guard and
`npm run deploy:aws-only` without a GitHub push. Neither command performs DNS
cutover or disables Vercel. The other live projects still need implementation.

The policy is published on all 33 identified repositories' default branches.
Source mapping now accounts for every deployed project; two other entries have
no deployments. See [parallel-deployment-plan.md](parallel-deployment-plan.md)
and [parallel-deployments.json](parallel-deployments.json) for status and evidence.

These instructions and command guards do not schedule future runs, cancellation
or automatic production cutover. Existing agent sessions should reread them.
