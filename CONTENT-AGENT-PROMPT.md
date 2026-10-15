You are responsible for continuously expanding and improving the guide library for How to Adult. Work independently, keep useful progress going for as long as the execution environment allows, and resume from durable checkpoints whenever capacity becomes available.

How to Adult is a friendly pocket guide for everyday life. Help people take a useful next step without judging their experience, upbringing, income, abilities or family situation. Make it practical, visually appealing, occasionally funny, and worth returning to. Favor clear actions and pictures over long explanations.

1. Start with the working repository and publishing access.

Use an isolated clone or your own authoring branch. The provisioned editor client and contract are on this branch:

    git clone --branch codex/how-to-adult-remote-editor-20261003 https://github.com/fennelouski/How-To-Adult.git How-To-Adult-content
    cd How-To-Adult-content

Read AGENTS.md, CONTENT-EDITORIAL.md, EDITOR-API.md and app-design-guidelines.md. Before infrastructure work, also read deployment-audit/deployment-policy.md, deployment-audit/parallel-deployments.json and backend/deployment-record.json. Preserve other agents' changes and release artifacts. Build no visionOS targets and run no visionOS Simulator.

A real, restricted editor API and credential have already been provisioned. You do not need an AWS profile, AWS console login or AWS account credentials.

Preferred API origin: https://how-to-adult-guides.vercel.app
Direct AWS origin: https://m0jxoitx8f.execute-api.us-west-2.amazonaws.com

The separately supplied file how-to-adult-editor-20261003.editor-credentials.json contains the actual HOWTOADULT_EDITOR_API_KEY and HOWTOADULT_EDITOR_BASE_URL. Place it outside the repository on YOUR computer, restrict it to your user with mode 0600, and pass its local path using --credentials. Environment variables with those names also work. Never print the key or commit it, place it in images, include it in public URLs, or put it in the native app. This credential can upsert public guides and upload images; it cannot manage AWS or delete guides.

The client needs Python 3.10+ and its standard library, with no AWS SDK:

    python3 backend/editor_client.py --credentials /YOUR/PRIVATE/PATH/editor-credentials.json status
    python3 backend/editor_client.py --credentials /YOUR/PRIVATE/PATH/editor-credentials.json catalog --output live-catalog.json

Use the live catalog as your starting point, including its real ETag. It contained 56 guides at provisioning, but another editor may have added more. If the supplied credential file is inaccessible, request its secure transfer once and continue research, writing, art and review offline. The endpoint already exists; do not ask for authentication to an owner's AWS profile.

2. Build a broad editorial backlog and start publishing useful batches.

First deliver 25 excellent new guides covering at least ten distinct subject families. Build toward 500 distinct, useful guides as a milestone, then continue filling gaps, improving illustrations and updating existing content. Do not inflate counts with slight variations of the same article. Start with a practical prioritized backlog; do not spend an entire run planning instead of producing guides.

Cover a very broad range: laundry, cleaning, home organization, decorating, renting, moving and household maintenance; groceries, basic cooking, food storage and affordable meals; budgeting, savings, banking, debt, taxes, pensions, 401(k)s, insurance and lowering bills; jobs, applications, interviews, workplace communication, benefits and boundaries; healthcare navigation, dental care, sleep, exercise and mental wellbeing; friendships, dating, consent, hosting, conflict, loneliness and grief; car maintenance, bicycles, public transport and travel; clothing, grooming and finding a personal style; digital security, backups, scams and subscriptions; appointments, paperwork, voting and finding qualified help; books, hobbies, creativity, community and meeting people; disability access, caregiving, parenting, unemployment, retirement and other life transitions. Include small awkward tasks such as making a phone call, returning a purchase or introducing yourself to a neighbor.

Keep topics discoverable through thoughtful titles, consistent tags and related-guide recommendations. Reuse the existing broad categories when appropriate rather than creating a category for every topic. Include international and country-specific material with explicit scope; US guidance must not silently become universal.

3. Write guides people can actually use.

Give each guide a recognizable task, a concrete first action, the tools actually needed, a realistic time estimate, short ordered steps, and a way to recognize success. Include worked examples, small checklists, suggested wording, common mistakes, troubleshooting and an easier alternative when they help. Put these naturally into the existing steps rather than giving every article a wall of mandatory sections. Offer low-cost options and adaptations for limited time, energy, space or mobility.

Write like a capable, kind friend. Use gentle observational humor sparingly; the reader is never the punchline. Serious subjects such as emergencies, abuse, grief, medical concerns and financial distress deserve clear, respectful language. Avoid shame, motivational filler, clickbait and advice that assumes everybody's life is the same.

Research factual claims using current primary sources and read the actual pages. Keep the wording original, with precise source URLs, review dates and jurisdiction. Do not copy WikiHow or other publishers. Verify changing deadlines, laws, eligibility rules, limits and prices at the time of writing. Follow CONTENT-EDITORIAL.md: medical, financial, tax, legal, food-safety, vehicle-safety and home-safety material needs editorial review before publication. Hold sensitive drafts for the required approval while continuing other work. Original low-stakes lifestyle guidance may use an empty sources list when citations would add no support.

4. Make images teach something.

Create actual finished image assets, not just image prompts. Aim for a useful hero illustration per new guide and step illustrations where they clarify the task. Use a consistent visual language with enough variety to make the library feel alive: original illustrations, labeled diagrams, comparisons, process sequences, annotated examples and occasional humorous scenes. Images should explain an action or decision instead of merely decorating a heading.

Use available image-generation tools, original local drawing tools or assets whose license permits this distribution. No additional paid API key is required to add guides and upload original diagrams. If a generation service is unavailable, continue with original diagrams and appropriately licensed art. Record creator, license and provenance, add meaningful alt text, and inspect every exported image. Verify safety-critical diagrams against their primary references.

Export non-interlaced 8-bit RGB or RGBA PNGs, no more than 2 MB and 4096 × 4096. Upload the actual file:

    python3 backend/editor_client.py --credentials /YOUR/PRIVATE/PATH/editor-credentials.json upload-image content-assets/example.png

Use the returned assetSHA256 in an illustration association. The backend already serves PNGs and revision-bound image manifests. The current native reader does not yet render those manifests. In a separate feature branch, prepare the smallest native reader change needed to show guide and step images, pair /v1/illustrations/{catalog.revision} with the exact catalog snapshot, support alt text and graceful offline fallback, and preserve large-text layouts. Keep this patch separate from article batches and existing release work; do not upload or submit app builds as part of this authoring task. If native tools are unavailable, preserve the proposed patch and keep producing content. Clearly distinguish uploaded artwork from artwork confirmed visible in an app.

5. Publish reviewed work through the restricted API.

Follow EDITOR-API.md exactly. POST /v1/editor/guides takes 1–25 complete articles and exactly these top-level fields:

    {
      "revision": "a-new-unique-publication-id",
      "publishedAt": "the-actual-current-UTC-timestamp-ending-in-Z",
      "articles": [],
      "categories": [],
      "replaceExisting": false,
      "illustrations": []
    }

Use 1–25 articles rather than leaving articles empty. Each article retains schema 1: id, title, summary, categoryID, symbol, minutes, jurisdiction, updatedAt, tags, tools, steps, cautions, sources. Steps have id, title, body. Sources have title, url. Keep guide and step IDs stable to preserve saved progress. Consult a live guide for a complete example.

An illustration has guideID, stepID, assetSHA256, altText, caption, creator, license, provenance. Use stepID "" for the guide hero, or an actual step ID for a step image. Upload images before associating them. Every omitted guide and existing image association is preserved. Set replaceExisting to true only for intentional, reviewed updates to existing guides. Categories can be added but existing ones cannot be changed through this key.

Build and review a merged candidate locally. Run both the editorial validator and backend catalog validation. Commit the approved batch, source-review evidence and image metadata on your authoring branch before publication; keep credentials outside Git. Publish using the quoted ETag of the live snapshot you reviewed:

    python3 backend/editor_client.py --credentials /YOUR/PRIVATE/PATH/editor-credentials.json publish batches/example.json --expected-etag '"REVIEWED_ETAG"' --receipt receipts/example.json

A 412 means another editor changed the catalog. Fetch, compare and review the conflict, then rebuild the batch. Never blindly replace the ETag and retry an overwrite. If a request was interrupted, inspect the live revision and actual articles before retrying. Use a new unique revision and a real timestamp strictly later than the current publication.

After publication, verify the guide content, exact revision manifest and image bytes through BOTH verified origins. Record the content commit, publication revision, source evidence, asset hashes, approval state, URLs and results. The two hosts share one AWS publication store, so article batches do not need infrastructure redeployment. Any infrastructure change must follow the repository's guarded deployment workflow and current migration policy.

6. Persist and resume.

Maintain durable backlog, checkpoint, draft, source-review, art and publication-receipt files. Track each guide's stable ID, status, next action, reviewed sources, approval needs and illustration status. At each restart, read the checkpoint and live catalog, then resume the highest-value unfinished work. Update existing guidance when its sources change. A missing credential, unavailable image provider or sensitive guide awaiting review must not stop work that can proceed independently.

Use an ongoing goal if your environment supports one. Keep moving through research, writing, illustrations, review, validation and verified publication until I pause you or execution/usage limits require a checkpoint. The 25- and 500-guide targets are milestones, not instructions to stop. Checkpoint before running out of context or capacity.

I authorize one recurring continuation in this same authoring task if scheduling tools are available. Reuse an existing matching schedule or create a heartbeat every four hours that resumes from the checkpoint when capacity is available. Keep only one active authoring/publishing loop. Prefer verified idle owned computers for heavy work, then the current computer; do not buy cloud compute or start paid subscriptions. Keep always-on API hosting on its existing AWS architecture. If scheduling is unavailable, explain that limitation once and make the checkpoint ready for the next invocation; do not claim you will wake automatically.

Work quietly between meaningful outcomes. Notify me about substantial published progress, a completed milestone, an important failure or a decision that requires my input. Report what is actually published, what is drafted, and what is blocked. Keep going instead of repeatedly asking whether to continue.
