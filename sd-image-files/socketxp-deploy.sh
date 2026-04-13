#!/bin/bash
# Deploy container update via SocketXP REST API
# Usage: socketxp-deploy.sh AUTH_TOKEN GROUP IMAGE_TAG

set -e

AUTH_TOKEN="$1"
GROUP="$2"
IMAGE_TAG="${3:-latest}"

if [ -z "$AUTH_TOKEN" ] || [ -z "$GROUP" ]; then
    echo "Usage: $0 AUTH_TOKEN GROUP [IMAGE_TAG]"
    exit 1
fi

echo "======================================"
echo "  SocketXP Remote Deployment"
echo "======================================"
echo "Device group: $GROUP"
echo "Image tag: $IMAGE_TAG"
echo ""

# Construct deployment command
DEPLOY_CMD="cd /home/pi/orcanode/node && export IMAGE_TAG='$IMAGE_TAG' && docker compose pull && docker compose up -d && docker compose ps"

# Execute command via SocketXP REST API on all devices in group
echo "Executing deployment command on group '$GROUP'..."
RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer $AUTH_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"group\":\"$GROUP\",\"command\":\"$DEPLOY_CMD\"}" \
    https://portal.socketxp.com/api/v1/groups/exec)

# Parse response
if echo "$RESPONSE" | grep -q '"status":"success"'; then
    echo "✓ Deployment command sent successfully to all devices in group '$GROUP'"
    echo ""
    
    # Display results for each device
    echo "Deployment results:"
    echo "$RESPONSE" | jq -r '.results[] | "  [\(.device_id)] \(.status): \(.output // .error)"' 2>/dev/null || echo "$RESPONSE"
else
    echo "✗ Deployment failed"
    echo "Response: $RESPONSE"
    exit 1
fi

echo ""
echo "✓ Deployment complete for group: $GROUP"