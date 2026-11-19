#!/usr/bin/env bash
# H0 evidence: the compiled lock must send Pi inference to Z.ai with the ZAI_API_KEY secret.
# Prints the route lines for review, then fails if the Z.ai route is missing.
set -euo pipefail

lock="${1:-.github/workflows/spike-pi-glm.lock.yml}"
[ -f "$lock" ] || { echo "::error::missing $lock"; exit 1; }

echo "== Engine and route lines in $lock"
grep -nE 'api\.z\.ai|ANTHROPIC_BASE_URL|ANTHROPIC_API_KEY|ZAI_API_KEY|model-provider|GH_AW_ENGINE|GH_AW_MODEL|--model|glm-' "$lock" | head -80 || true

echo "== Copilot mentions (review by hand; detection is off in the spike)"
grep -niE 'copilot' "$lock" | head -40 || true

fail=0
# The API proxy is the agent's only way out to a model. Its single target must be Z.ai.
grep -qF '\"targets\":{\"anthropic\":{\"host\":\"api.z.ai\"}}' "$lock" \
  || { echo "::error::API proxy target is not anthropic -> api.z.ai"; fail=1; }
grep -qF -- '--anthropic-api-base-path /api/anthropic' "$lock" \
  || { echo "::error::proxy base path is not /api/anthropic"; fail=1; }
grep -qF 'GH_AW_LLM_PROVIDER=anthropic' "$lock" \
  || { echo "::error::Pi provider is not anthropic"; fail=1; }
grep -qF -- '--exclude-env COPILOT_GITHUB_TOKEN' "$lock" \
  || { echo "::error::Copilot token is not excluded from the agent"; fail=1; }
grep -qF 'secrets.ZAI_API_KEY' "$lock" || { echo "::error::lock does not read ZAI_API_KEY"; fail=1; }
grep -qF 'glm-5.3' "$lock"             || { echo "::error::lock does not pin glm-5.3"; fail=1; }

[ "$fail" -eq 0 ] && echo "H0 route check passed"
exit "$fail"
