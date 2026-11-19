# Spike: Pi on the GLM Coding Plan inside gh-aw

Goal: prove the riskiest assumptions of the gh-aw route in one run, before building workers.
Time box: half a day.

![Spike run](images/spike.png)

## Hypotheses

| ID | Hypothesis | Pass signal |
|---|---|---|
| H0 | The workflow compiles with the Pi engine on a Z.ai route | compile succeeds and `scripts/check-lock-route.sh` passes: the API proxy's only target is `api.z.ai/api/anthropic` |
| H1 | Pi reaches `api.z.ai` through the AWF firewall | firewall log shows allowed requests to `api.z.ai`, none blocked |
| H2 | GLM answers and calls tools | agent log shows GLM responses and at least one successful tool call |
| H3 | Pi follows the vendored Clarity skill | agent log reads `.agents/skills/clarity/references/interview.md`; the comment has prompts, no prose |
| H4 | Prompts arrive as one issue comment | exactly one harness comment on the test issue |
| H5 | Notes reach a draft PR without local state | draft PR `[spike] ...` adds only `spike/notes/<n>.md` |
| H6 | The run fits the budget | under 15 minutes; calls appear under the Coding Plan quota |
| H7 | The agent reads ideas from every account the writer uses | notes name the reader and outcome from the issue; no `DIFC_FILTERED` event; an untrusted author gets a "could not read" comment and no PR |
| H8 | The PR coaches the writer | body is the illustration, one bold question, at most two plain sentences, and "Your next move"; no technical detail |

The same hypotheses are manual acceptance scenarios in `features/spike/pi_glm_spike.feature`,
tagged `@manual`. No step runner exists yet, so check each one by hand against the run evidence.

## Setup

1. Repository secret `ZAI_API_KEY`: your GLM Coding Plan key. Labels: run
   `scripts/setup-labels.sh` once (the `spike` label is required by the PR output).
2. Install the CLI: `gh extension install github/gh-aw` (this guide follows the v1.2.3 docs).
3. Compile: `gh aw compile spike-pi-glm`. The first compile stops at gh-aw's security review
   because the workflow adds a new secret, `ZAI_API_KEY`. Check that the secret only feeds the
   engine's `ANTHROPIC_API_KEY`, then run `gh aw compile spike-pi-glm --approve`. Run
   `scripts/check-lock-route.sh` to confirm the lock routes inference to `api.z.ai` (H0).
   Commit and push the `.lock.yml` to the default branch: GitHub only runs `issue_comment`
   workflows from the default branch, so `/spike` does nothing until the lock is on `main`.
   From your phone, the **Agentic workflow compile check** action runs the same compile and
   route check without committing.
4. Open a test issue with a rough article idea in the body.
5. Comment `/spike`.

## Reading the evidence

- Run summary in the Actions tab: agent log, firewall log, safe-output results.
- `gh aw logs spike-pi-glm` downloads recent runs.
- `gh aw audit <run-id>` explains a single run, including model and tool usage.

## If something fails

| Failure | Try next |
|---|---|
| H0: compile rejects route A | Route B, the OpenAI Responses endpoint (below) |
| H1: firewall blocks | Check `network.allowed` includes `api.z.ai`; read the firewall log for the exact host |
| H2: `model_unavailable` | Try `zai/glm-4.7`. gh-aw strips the `zai/` prefix, so Z.ai receives `glm-5.3` or `glm-4.7` |
| H3: skill not read | Move the Clarity steps into an inline `## skill:` block in the workflow |
| H5: no PR | Check the safe-outputs job log; protected-file rules may have blocked the patch |
| H0 to H2 fail on both routes | Stop. Fall back to option A: plain Actions jobs running `pi -p` |

Route B replaces the `engine` block in `.github/workflows/spike-pi-glm.md`:

```yaml
engine:
  id: pi
  model: zai/glm-5.3
  model-provider: openai
  env:
    OPENAI_BASE_URL: https://api.z.ai/api/v1
    OPENAI_API_KEY: ${{ secrets.ZAI_API_KEY }}
```

gh-aw sends Pi's OpenAI-family traffic through the Responses API. Z.ai documents
`https://api.z.ai/api/v1` as its Coding Plan Responses endpoint.

## Decision record

Filled in after the runs on 2026-11-19. Route A and Route B as first written both
failed for the same hidden reason: a `zai/` model prefix makes Pi speak OpenAI wire
(`POST /chat/completions`) no matter what `model-provider` says.

| Hypothesis | Result | Evidence link |
|---|---|---|
| H0 | Pass (compiler v1.2.2, Pi 1.5.0). Lock routes anthropic → `api.z.ai`, base path `/api/anthropic`; the Copilot token is excluded; threat detection is off. Working config: **bare `glm-5.3` + `model-provider: anthropic`** — the `zai/` prefix had to go. | [run 44436753325](https://github.com/rajchampaneriya/rajc-article-harness/actions/runs/44436753325) |
| H1 | Pass. Firewall access log shows `CONNECT api.z.ai:443` tunnels allowed, none blocked. | run artifacts, `sandbox/firewall/logs/access.log` |
| H2 | Pass. GLM-5.3 answered and called tools (~18 AIC, ~12K tokens): one interview comment, one notes file. | [issue #3 comment](https://github.com/rajchampaneriya/rajc-article-harness/issues/3#issuecomment-6996787849) |
| H3 | Pass. Agent read `SKILL.md` and `references/interview.md`; the comment is prompts only, no article prose. | same comment, "Spike evidence" list |
| H4 | Pass. Exactly one harness comment on the issue. | same |
| H5 | Pass after one repo setting. The patch added only `spike/notes/3.md` (19 lines). Runs before the setting change pushed branch `spike/interview-notes-3-*` and fell back to issue #5; enable "Allow GitHub Actions to create and approve pull requests" under Settings → Actions → General → Workflow permissions. | [issue #5](https://github.com/rajchampaneriya/rajc-article-harness/issues/5) |
| H6 | Pass. Minutes-scale run, well under the 15-minute timeout; ~18 AIC. | run summary |

**Decision:** option B (gh-aw). The firewall, safe outputs and skill loading all work
with GLM on the Coding Plan. Two gotchas for the production workers:

1. **Model id must stay bare** (`glm-5.3`, no `zai/` prefix) with `model-provider: anthropic`.
   The prefix switches Pi to OpenAI wire, and the GLM Coding Plan key is denied on
   `/chat/completions` for every model (`model_access_denied`) — it only serves
   Anthropic `/v1/messages` and `/v1/responses`.
2. **Wrong keys fail as silent stream drops, not 401s.** A key with no balance
   (`[1113] Insufficient balance`) makes Z.ai open the SSE stream and close it with
   zero tokens — Pi logs `Stream ended without finish_reason`. Check the key with a
   direct curl before debugging the workflow.

### Follow-up: issue #7 arrived empty (2026-11-19)

Issue #7 was opened from `raj-champaneriya-ibm`, the writer's second account. On a public repo
gh-aw applies `min-integrity: approved` automatically, and that account's association is
`CONTRIBUTOR` (unapproved), so the GitHub MCP gateway removed the issue before GLM saw it. The run
still reported success and opened PR #8 with `[TK]` placeholders. Issue #3, opened by the owner
account, was unaffected.

Fix: `tools.github.trusted-users: [raj-champaneriya-ibm]` with `min-integrity: approved`, plus a
prompt rule to stop and say so when the issue is unreadable (H7). `gh aw logs --filtered-integrity`
lists runs where this happens.
