#!/usr/bin/env bash
# /cross-review backend dispatcher.
#
# Sends a code-review prompt about the current branch's diff vs main
# to a configurable OAuth-backed reviewer model from a different vendor.
#
# Usage:  review.sh [profile-name]
# Env:    CROSS_REVIEW_BASE  base ref for the diff (default: main)
#
# Reads profiles.json (or profiles.example.json as fallback) from the skill dir.
# Backends: azure-foundry-openai, azure-foundry-inference, github-models, copilot-cli.
# All backends use OAuth, no static API keys.
#
# Output: prints findings to stdout AND saves a copy at
#         flow/reviews/<branch>-cross-review-<timestamp>.md

set -euo pipefail

# --- Locate skill dir + profiles
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROFILES_FILE="${SKILL_DIR}/profiles.json"
if [ ! -f "$PROFILES_FILE" ]; then
  if [ -f "${SKILL_DIR}/profiles.example.json" ]; then
    PROFILES_FILE="${SKILL_DIR}/profiles.example.json"
    echo "WARN: profiles.json not found; using profiles.example.json. Copy it to profiles.json and customise." >&2
  else
    echo "ERROR: no profiles file under $SKILL_DIR" >&2
    exit 2
  fi
fi

# --- Prerequisites that every run needs
for cmd in jq curl git; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' not installed." >&2; exit 3; }
done

# --- Resolve profile
PROFILE_ARG="${1:-}"
DEFAULT_PROFILE="$(jq -r '.default // empty' "$PROFILES_FILE")"
PROFILE_NAME="${PROFILE_ARG:-$DEFAULT_PROFILE}"
if [ -z "$PROFILE_NAME" ]; then
  echo "ERROR: no profile specified and no .default in $(basename "$PROFILES_FILE")." >&2
  echo "Available: $(jq -r '.profiles | keys | join(", ")' "$PROFILES_FILE")" >&2
  exit 2
fi
PROFILE_JSON="$(jq -c --arg name "$PROFILE_NAME" '.profiles[$name] // empty' "$PROFILES_FILE")"
if [ -z "$PROFILE_JSON" ] || [ "$PROFILE_JSON" = "null" ]; then
  echo "ERROR: profile '$PROFILE_NAME' not found in $(basename "$PROFILES_FILE")." >&2
  echo "Available: $(jq -r '.profiles | keys | join(", ")' "$PROFILES_FILE")" >&2
  exit 2
fi
BACKEND="$(echo "$PROFILE_JSON" | jq -r '.backend // empty')"
if [ -z "$BACKEND" ]; then
  echo "ERROR: profile '$PROFILE_NAME' missing .backend" >&2
  exit 2
fi

# Helper: extract a required field from the profile or fail with a clear message.
require_field() {
  local key="$1"
  local val
  val="$(echo "$PROFILE_JSON" | jq -r --arg k "$key" '.[$k] // empty')"
  if [ -z "$val" ]; then
    echo "ERROR: profile '$PROFILE_NAME' missing field .$key" >&2
    exit 2
  fi
  printf '%s' "$val"
}

# --- Compute diff vs base
BASE_REF="${CROSS_REVIEW_BASE:-main}"
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  echo "ERROR: base ref '$BASE_REF' not found (set CROSS_REVIEW_BASE to override)." >&2
  exit 2
fi
DIFF="$(git diff "${BASE_REF}...HEAD")"
if [ -z "$DIFF" ]; then
  echo "INFO: no diff between $BASE_REF and HEAD; nothing to review." >&2
  exit 0
fi
DIFF_LINES="$(printf '%s\n' "$DIFF" | wc -l)"
if [ "$DIFF_LINES" -gt 5000 ]; then
  echo "WARN: diff is ${DIFF_LINES} lines; may exceed reviewer context. Consider narrowing with CROSS_REVIEW_BASE=<closer-ref>." >&2
fi

# --- Build review prompt
PROMPT_HEADER="$(cat <<'EOF'
You are an ADVISORY code reviewer. Another model wrote the change shown below as a unified diff; you are a SECOND opinion from a different vendor.

INSTRUCTIONS:
- Report ONLY HIGH or CRITICAL findings: correctness bugs, security issues (injection, auth bypass, secret leakage, unsafe deserialisation), logic errors, race conditions, data-loss risk, regressions, broken invariants.
- SKIP nitpicks, style, naming, doc wording, minor refactors. Existing style is intentional.
- For each finding, give: file:line, severity (HIGH or CRITICAL), what is wrong, why it matters.
- If there are no HIGH or CRITICAL issues, reply exactly: "No high or critical issues found."
- Do NOT propose code rewrites; describe the issue and let the human decide how to fix.

DIFF:
EOF
)"
PROMPT="${PROMPT_HEADER}
${DIFF}"

# --- Backend dispatch
RESPONSE_TEXT=""
MODEL_LABEL=""

case "$BACKEND" in

  azure-foundry-openai)
    ENDPOINT="$(require_field endpoint)"
    DEPLOYMENT="$(require_field deployment)"
    command -v az >/dev/null 2>&1 || { echo "ERROR: 'az' CLI not installed." >&2; exit 3; }
    # Foundry next-gen v1: NO api-version query; the /openai/v1/ path IS the version.
    # Entra scope for the v1 endpoint is ai.azure.com (not the legacy cognitiveservices).
    if ! TOKEN="$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv 2>/dev/null)"; then
      echo "ERROR: 'az account get-access-token' failed. Run 'az login' first." >&2
      exit 3
    fi
    URL="${ENDPOINT%/}/openai/v1/chat/completions"
    PAYLOAD="$(jq -n --arg p "$PROMPT" --arg m "$DEPLOYMENT" \
      '{model:$m, messages:[{role:"user",content:$p}], temperature:0.2, max_tokens:4096}')"
    if ! HTTP_RESPONSE="$(curl -sS -X POST "$URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary "$PAYLOAD" 2>&1)"; then
      echo "ERROR: HTTP request to $URL failed: $HTTP_RESPONSE" >&2
      exit 4
    fi
    RESPONSE_TEXT="$(printf '%s' "$HTTP_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)"
    if [ -z "$RESPONSE_TEXT" ]; then
      RESPONSE_TEXT="(no content from model; raw response below)
\`\`\`
${HTTP_RESPONSE}
\`\`\`"
    fi
    MODEL_LABEL="azure-foundry-openai: deployment=${DEPLOYMENT}, endpoint=${ENDPOINT}"
    ;;

  azure-foundry-inference)
    ENDPOINT="$(require_field endpoint)"
    MODEL="$(require_field model)"
    API_VERSION="$(echo "$PROFILE_JSON" | jq -r '.api_version // "2024-05-01-preview"')"
    command -v az >/dev/null 2>&1 || { echo "ERROR: 'az' CLI not installed." >&2; exit 3; }
    # Azure AI Inference endpoint (/models/chat/completions) is DEPRECATED; retires 2026-08-26.
    # Legacy Entra scope: cognitiveservices.azure.com (different from v1 above).
    if ! TOKEN="$(az account get-access-token --scope https://cognitiveservices.azure.com/.default --query accessToken -o tsv 2>/dev/null)"; then
      echo "ERROR: 'az account get-access-token' failed. Run 'az login' first." >&2
      exit 3
    fi
    URL="${ENDPOINT%/}/models/chat/completions?api-version=${API_VERSION}"
    PAYLOAD="$(jq -n --arg p "$PROMPT" --arg m "$MODEL" \
      '{model:$m, messages:[{role:"user",content:$p}], temperature:0.2, max_tokens:4096}')"
    if ! HTTP_RESPONSE="$(curl -sS -X POST "$URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        --data-binary "$PAYLOAD" 2>&1)"; then
      echo "ERROR: HTTP request to $URL failed: $HTTP_RESPONSE" >&2
      exit 4
    fi
    RESPONSE_TEXT="$(printf '%s' "$HTTP_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)"
    if [ -z "$RESPONSE_TEXT" ]; then
      RESPONSE_TEXT="(no content from model; raw response below)
\`\`\`
${HTTP_RESPONSE}
\`\`\`"
    fi
    MODEL_LABEL="azure-foundry-inference (DEPRECATED, retires 2026-08-26): model=${MODEL}, endpoint=${ENDPOINT}"
    ;;

  github-models)
    MODEL="$(require_field model)"
    GH_API_VERSION="$(echo "$PROFILE_JSON" | jq -r '.api_version // "2026-03-10"')"
    command -v gh >/dev/null 2>&1 || { echo "ERROR: 'gh' CLI not installed." >&2; exit 3; }
    if ! TOKEN="$(gh auth token 2>/dev/null)"; then
      echo "ERROR: 'gh auth token' failed. Run 'gh auth login' first." >&2
      exit 3
    fi
    URL="https://models.github.ai/inference/chat/completions"
    PAYLOAD="$(jq -n --arg p "$PROMPT" --arg m "$MODEL" \
      '{model:$m, messages:[{role:"user",content:$p}], temperature:0.2, max_tokens:4096}')"
    if ! HTTP_RESPONSE="$(curl -sS -X POST "$URL" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "X-GitHub-Api-Version: ${GH_API_VERSION}" \
        -H "Accept: application/vnd.github+json" \
        --data-binary "$PAYLOAD" 2>&1)"; then
      echo "ERROR: HTTP request to $URL failed: $HTTP_RESPONSE" >&2
      exit 4
    fi
    RESPONSE_TEXT="$(printf '%s' "$HTTP_RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)"
    if [ -z "$RESPONSE_TEXT" ]; then
      RESPONSE_TEXT="(no content from model; raw response below)
\`\`\`
${HTTP_RESPONSE}
\`\`\`"
    fi
    MODEL_LABEL="github-models: model=${MODEL}"
    ;;

  copilot-cli)
    MODEL="$(echo "$PROFILE_JSON" | jq -r '.model // "auto"')"
    command -v copilot >/dev/null 2>&1 || {
      echo "ERROR: 'copilot' CLI not installed. See https://docs.github.com/copilot/concepts/agents/about-copilot-cli" >&2
      exit 3
    }
    # -p: prompt; -s: silent (suppress usage stats); --allow-all-tools required for programmatic use;
    # --deny-tool=write blocks file modifications so the review stays read-only.
    if ! RESPONSE_TEXT="$(copilot -p "$PROMPT" -s --model="$MODEL" --allow-all-tools --deny-tool=write 2>&1)"; then
      echo "ERROR: copilot CLI invocation failed:" >&2
      echo "$RESPONSE_TEXT" >&2
      exit 4
    fi
    MODEL_LABEL="copilot-cli: model=${MODEL}"
    ;;

  *)
    echo "ERROR: unknown backend '$BACKEND' in profile '$PROFILE_NAME'." >&2
    echo "Supported: azure-foundry-openai, azure-foundry-inference, github-models, copilot-cli." >&2
    exit 2
    ;;
esac

# --- Save and print
REPO_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git branch --show-current | tr '/' '-')"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="${REPO_ROOT}/flow/reviews"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="${OUTPUT_DIR}/${BRANCH}-cross-review-${TIMESTAMP}.md"

cat > "$OUTPUT_FILE" <<EOF
---
profile: ${PROFILE_NAME}
backend: ${BACKEND}
model: ${MODEL_LABEL}
base_ref: ${BASE_REF}
branch: $(git branch --show-current)
timestamp: ${TIMESTAMP}
---

# Cross-vendor review

**Advisory only.** A second-opinion review from a different-lineage model. Apply human judgement; the reviewer may be wrong.

## Findings

${RESPONSE_TEXT}
EOF

echo "=== Cross-vendor review (profile=${PROFILE_NAME}, backend=${BACKEND}) ==="
echo ""
echo "${RESPONSE_TEXT}"
echo ""
echo "Saved: ${OUTPUT_FILE}"
