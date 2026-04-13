#!/bin/bash
# Rename Orcanode Node
# Changes hostname, NODE_NAME, and restarts services
# Usage: sudo rename-node.sh <new_hostname>

set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root"
    echo "Usage: sudo rename-node.sh <new_hostname>"
    exit 1
fi

# Check if hostname provided
if [ -z "$1" ]; then
    echo "Error: No hostname provided"
    echo "Usage: sudo rename-node.sh <new_hostname>"
    echo ""
    echo "Examples:"
    echo "  sudo rename-node.sh rpi_bush_point"
    echo "  sudo rename-node.sh orcanode_seattle_01"
    exit 1
fi

NEW_HOSTNAME="$1"

# Validate hostname (lowercase alphanumeric, hyphens, underscores)
if ! echo "$NEW_HOSTNAME" | grep -qE '^[a-z0-9_-]+$'; then
    echo "Error: Invalid hostname: $NEW_HOSTNAME"
    echo "Hostname must contain only lowercase letters, numbers, hyphens, and underscores"
    echo ""
    echo "Valid examples:"
    echo "  rpi_bush_point"
    echo "  orcanode-seattle-01"
    echo "  orcasound_lime_kiln"
    exit 1
fi

CURRENT_HOSTNAME=$(hostname)

echo "======================================"
echo "  Orcanode Node Rename Utility"
echo "======================================"
echo ""
echo "Current hostname: $CURRENT_HOSTNAME"
echo "New hostname:     $NEW_HOSTNAME"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Setting system hostname..."
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "✓ System hostname set to: $NEW_HOSTNAME"

echo ""
echo "Step 2: Updating /etc/hosts..."
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
echo "✓ /etc/hosts updated"

echo ""
echo "Step 3: Updating NODE_NAME in orcanode configuration..."
ENV_FILE="/home/pi/orcanode/node/.env"

if [ ! -d "/home/pi/orcanode/node" ]; then
    echo "⚠ Warning: Orcanode not yet installed at /home/pi/orcanode/node"
    echo "  NODE_NAME will be set when orcanode is installed"
else
    if [ -f "$ENV_FILE" ]; then
        # Update existing NODE_NAME
        if grep -q "^NODE_NAME=" "$ENV_FILE"; then
            sed -i "s/^NODE_NAME=.*/NODE_NAME=$NEW_HOSTNAME/" "$ENV_FILE"
            echo "✓ Updated NODE_NAME in $ENV_FILE"
        else
            # Add NODE_NAME if missing
            echo "NODE_NAME=$NEW_HOSTNAME" >> "$ENV_FILE"
            echo "✓ Added NODE_NAME to $ENV_FILE"
        fi
    else
        # Create .env with NODE_NAME
        echo "NODE_NAME=$NEW_HOSTNAME" > "$ENV_FILE"
        chown pi:pi "$ENV_FILE"
        echo "✓ Created $ENV_FILE with NODE_NAME"
    fi
fi

echo ""
echo "Step 4: Checking if orcanode container is running..."
if docker ps --format '{{.Names}}' | grep -q orcanode; then
    echo "Orcanode container is running. Restarting to apply new NODE_NAME..."
    cd /home/pi/orcanode/node
    docker compose down
    docker compose up -d
    echo "✓ Orcanode container restarted"
else
    echo "⚠ Orcanode container not currently running"
    echo "  Start it manually when ready: cd ~/orcanode/node && docker compose up -d"
fi

echo ""
echo "======================================"
echo "  Hostname Change Complete!"
echo "======================================"
echo ""
echo "Changes applied:"
echo "  • System hostname: $CURRENT_HOSTNAME → $NEW_HOSTNAME"
echo "  • /etc/hosts updated"
echo "  • NODE_NAME in .env: $NEW_HOSTNAME"
echo "  • Container restarted (if running)"
echo ""
echo "⚠ IMPORTANT: Reboot recommended for full hostname change"
echo ""
read -p "Reboot now? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 3 seconds..."
    sleep 3
    reboot
else
    echo "Reboot skipped. Run 'sudo reboot' manually when ready."
    echo ""
    echo "Note: Some services may still show old hostname until reboot."
fi