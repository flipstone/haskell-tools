#!/usr/bin/env sh

echo "Running stan..."

REPORT=$(stan report --json-output "$@")
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "$REPORT"
  exit $EXIT_CODE
fi

set -o errexit

OBSERVATIONS=$(echo "$REPORT" | jq '.observations')
LENGTH=$(echo "$OBSERVATIONS" | jq length)

if [ "$LENGTH" -gt 0 ]; then
  echo "stan found the following problems:"
  echo "$OBSERVATIONS" | jq -r '.[] | "- \(.inspectionId): \(.srcSpan)"'
  echo "See stan.html or run 'stan' for more information."
  exit 1
else
  echo "stan found no problems."
fi
