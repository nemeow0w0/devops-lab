#!/bin/bash
# strict-demo

set -euo pipefail


ls /nothimg | wc -l
echo "after pipe: $?"

ls /nothing
echo "still running..."
