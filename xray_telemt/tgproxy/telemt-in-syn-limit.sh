#!/bin/sh
set -eu

CONTAINER="${1:-telemt}"
TABLE="telemt_limit"
CHAIN="forward"
PORT="${PORT:-443}"
RATE="${RATE:-1/second}"
BURST="${BURST:-1}"
METER_TIMEOUT="${METER_TIMEOUT:-60s}"

IP=""

for i in $(seq 1 60); do
    RUNNING="$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)"
    if [ "$RUNNING" = "true" ]; then
        IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{"\n"}}{{end}}' "$CONTAINER" | awk 'NF {print; exit}')"
        if [ -n "$IP" ]; then
            break
        fi
    fi
    sleep 1
done

if [ -z "$IP" ]; then
    echo "Could not get IP for container: $CONTAINER" >&2
    exit 1
fi

nft delete table inet "$TABLE" 2>/dev/null || true
nft add table inet "$TABLE"
nft "add chain inet $TABLE $CHAIN { type filter hook forward priority 0; policy accept; }"

nft "add rule inet $TABLE $CHAIN ip daddr $IP tcp dport $PORT tcp flags & (syn | ack) == syn meter telemt_in_syn_per_client { ip saddr timeout $METER_TIMEOUT limit rate over $RATE burst $BURST packets } counter drop comment \"telemt_in_syn_per_client_${RATE}_burst_${BURST}\""

echo "Applied telemt inbound SYN per-client limiter:"
echo "container=$CONTAINER ip=$IP port=$PORT rate=$RATE burst=$BURST meter_timeout=$METER_TIMEOUT"
nft list chain inet "$TABLE" "$CHAIN"
