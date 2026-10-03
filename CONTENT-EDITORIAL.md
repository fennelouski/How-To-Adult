# How to Adult editorial guide

The library gives people a useful next action without judging what they already know. Write for someone who wants to do the task now. Never speculate about their upbringing, intelligence, income or family support.

## Starter catalog

`Content/catalog.json` is the bundled and public catalog. Revision `2026-10-03-starter-1` contains 56 original guides and 224 steps across Home, Food, Money, Work, Wellbeing, People and Everyday. There are 38 distinct primary source URLs. The articles use original wording and practical suggestions, not copied WikiHow instructions.

The first library is English. Everyday guidance uses `General` when the instructions do not promise a country's particular rights or services. US credit reports, credit cards, federal tax filing, 401(k)s, pay-stub terminology, broadband labels, mental-health crisis contacts and the NHTSA recall lookup explicitly use `United States`. A US government source can support a general food-safety or physical-activity fact without making US services available everywhere.

Article `minutes` is a rough estimate for the task or first useful session, not a guaranteed reading time. A car-maintenance planning guide does not include the time a garage needs to service the car. A cooking guide includes approximate cooking time. Show these estimates without promising an outcome or hiding longer waits.

## Write a guide

- Start with a recognizable task, such as checking a tire or making a bill calendar. Give it a stable lowercase slug.
- Use a short title and one practical summary. Give each step a verb and a concrete action. Three to six steps usually fit a first session.
- Make tools a short list of what the person really needs. Do not invent a purchase where an existing item works.
- Give the person a way to check the result and a sensible next action. Explain when to stop and ask for qualified help if that matters.
- Avoid shame, universal life rules, financial guarantees, medical diagnosis and claims that one routine works for everybody.
- Keep safety information visible near the relevant task. Use specific cautions instead of adding a generic warning to every article.
- Treat personal information as private. Do not ask people to put tax identifiers, medical records, account credentials or full financial statements into a shared checklist.

## Sources and review

Check facts on current primary sources before publication. Appropriate sources include the relevant tax authority, financial regulator, public-health agency, food-safety agency, vehicle authority, manufacturer and professional organization. Search summaries help locate a document; review the source itself when a precise threshold or procedure matters. A valid URL is not proof that the advice is accurate.

The starter articles were researched on 2026-10-03 using IRS, US Department of Labor and EBSA, CFPB, FTC, CDC, NIH, USDA, FoodSafety.gov, FDA, NHTSA, US Fire Administration, US Department of Energy, FCC and the American Dental Association. Laundry guides also cite relevant Whirlpool and Tide manufacturer instructions without recommending their products. Original low-stakes lifestyle suggestions, such as trying an outfit, choosing a book or sending a friendly invitation, have an empty source list rather than unrelated authority links.

Keep citations close to the article. Cite the page that supports the actual claim, not a search result or a generic agency homepage. Read linked sources critically and paraphrase. Do not reproduce an article, copy its sequence verbatim or keep changing a few words in someone else's instructions. Limit any excerpt and follow the source's copyright terms.

For health, money, tax, law, car safety, food safety and home safety, require editorial review before publishing. Include a primary source, a real review date and the applicable jurisdiction. Medical content gives general education and a route to care. Financial content explains decisions without picking an investment or assuring returns. Local law and an individual's situation may require professional advice.

Prefer linking current tax deadlines, eligibility and contribution limits over hard-coding a volatile number. If a number is necessary, name the tax year or policy version, check it against the primary document and set a review reminder. Never treat an old source's publication date as proof it still applies.

Recheck sensitive content before a native release and when a source changes. Review other articles at least annually. A broken or blocked link is a reason to investigate, not a reason to silently substitute an invented citation. Preserve source-review evidence and record limitations. The current source review is in `Content/source-review.json`.

## Add or update content

1. Edit or add an article in a working copy of the catalog. Reuse a category where it fits. Keep existing article and step IDs stable so saved progress survives an update. Append descriptive IDs for new steps rather than renumbering old IDs to reflect their new position.
2. Update `updatedAt` only after reviewing that article. Change the catalog `revision` and its UTC `publishedAt` when preparing a new catalog release. The timestamp describes the catalog release document, not proof of a backend deployment.
3. Run `python3 scripts/content_validate.py --self-test`. The validator checks shape, IDs, category references, bounds, dates, HTTPS citations, sensitive-source presence and US scope for the starter guides. It cannot decide whether a source is primary or instructions are accurate.
4. Review the changed guides on an actual native screen, including large text. Check search tags, step wording, cautions and source opening. Use the backend's documented authenticated publisher and deployment process. Keep production on the last verified revision until the new revision passes checks.
5. Record the published revision and verify the real public endpoint. Hosted releases must follow the workspace AWS/Vercel parallel-deployment policy. A commit alone is not a deployment.

## Future daily additions

The owner intends to set up a daily writing loop later. No schedule or automatic publishing is enabled by this catalog. A future generator should write candidates into a review queue with their sources and dates. Validate structure, check factual claims and originality, and approve a revision before it reaches the public catalog. Financial, medical and legal material must not publish unattended. Use one active scheduler to avoid duplicate jobs and articles.

The current seven-category catalog supports hundreds of guides without new categories for every subject. Keep titles specific, tags consistent and article IDs permanent. Introduce translations or a new schema version deliberately, with native fallback behavior and a migration plan.
