#!/usr/bin/env sh

echo "Running stan..."

REPORT=$(stan report --json-output "$@")
EXIT_CODE=$?

set -o errexit

OBSERVATIONS=$(echo "$REPORT" | jq -R 'try fromjson | .observations')

if [ -n "$OBSERVATIONS" ]; then
  LENGTH=$(echo "$OBSERVATIONS" | jq 'length')

  if [ "$LENGTH" -gt 0 ]; then
    echo "stan found the following problems:"
    echo "$OBSERVATIONS" | jq -r '.[] | "- \(.inspectionId): \(.srcSpan)"'
    echo "See stan.html or run 'stan' for more information."
    exit 1
  else
    echo "stan found no problems."
    exit 0
  fi
else
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "stan command failed with the following output:"
    echo "$REPORT"
    exit "$EXIT_CODE"
  else
    echo "Unexpected output from stan:"
    echo "$REPORT"
    exit 1
  fi
fi
