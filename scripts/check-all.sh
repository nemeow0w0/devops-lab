#!/bin/bash

set -u


FAILED=0


for SVC in nginx ssh cron ufw; do
    if ! ./check-service.sh "$SVC"; then
	FAILED=$((FAILED + 1))
    fi
done

echo "---"
echo "Failed: $FAILED"


if [ "$FAILED" -gt 0 ]; then
   exit 1
fi
