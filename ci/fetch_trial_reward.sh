#!/bin/bash
# Download one GitHub Actions artifact from the current workflow run and copy the
# first reward.json inside it to $OUT.
#
# Usage (inside a workflow step, where GH_TOKEN/GITHUB_API_URL/GITHUB_REPOSITORY/
# GITHUB_RUN_ID are already set):
#
#     bash ci/fetch_trial_reward.sh harbor-oracle-trial-exam003 evidence/harbor_oracle_reward.json
#
# Exits non-zero when the artifact or the reward.json inside it is missing, so a
# job cannot silently publish evidence that does not exist.

set -euo pipefail

ARTIFACT="${1:?usage: fetch_trial_reward.sh <artifact-name> <output-path>}"
OUT="${2:?usage: fetch_trial_reward.sh <artifact-name> <output-path>}"

: "${GITHUB_API_URL:?GITHUB_API_URL is not set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is not set}"
: "${GH_TOKEN:?GH_TOKEN is not set}"

api="$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID/artifacts"
echo "== listing artifacts of run $GITHUB_RUN_ID"
curl -sSL -H "Authorization: Bearer $GH_TOKEN" "$api" \
    | python3 ci/list_artifacts.py "$ARTIFACT" > /tmp/artifact_url.txt
url="$(cat /tmp/artifact_url.txt)"
if [ -z "$url" ]; then
    echo "FAIL: artifact '$ARTIFACT' not found in run $GITHUB_RUN_ID"
    exit 1
fi

echo "== downloading $ARTIFACT"
curl -sSL -H "Authorization: Bearer $GH_TOKEN" "$url" -o /tmp/trial.zip
unzip -l /tmp/trial.zip | head -n 40

rm -rf /tmp/trial
unzip -o /tmp/trial.zip -d /tmp/trial >/dev/null

target="$(find /tmp/trial -name reward.json | head -n1)"
if [ -z "$target" ]; then
    echo "FAIL: the artifact contains no reward.json"
    exit 1
fi

mkdir -p "$(dirname "$OUT")"
cp "$target" "$OUT"
echo "== copied $target -> $OUT"
echo "== contents (written by the task's own verifier, not by this script):"
cat "$OUT"
echo
