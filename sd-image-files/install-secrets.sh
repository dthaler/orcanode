#!/bin/bash
# Decrypt and install remote access tokens on first boot

set -e

ENCRYPTED_FILE="/usr/local/etc/orcanode-secrets.enc"
DECRYPTED_FILE="/tmp/orcanode-secrets"

# Check if encrypted secrets file exists
if [ ! -f "$ENCRYPTED_FILE" ]; then
    echo "No encrypted secrets file found - skipping remote access configuration"
    exit 0
fi

echo "Decrypting secrets..."

# Try to decrypt using the pi user's password hash as the key
# This leverages the fact that the password was set during image build
PASSWORD_HASH=$(sudo getent shadow pi | cut -d: -f2)

# Use a stable derivation of the password hash as the encryption key
# We use the first 32 characters of the SHA256 hash as a passphrase
PASSPHRASE=$(echo -n "$PASSWORD_HASH" | sha256sum | cut -d' ' -f1 | cut -c1-32)

# Decrypt using OpenSSL (AES-256-CBC)
if ! echo "$PASSPHRASE" | openssl enc -aes-256-cbc -d -pbkdf2 -in "$ENCRYPTED_FILE" -out "$DECRYPTED_FILE" -pass stdin 2>/dev/null; then
    echo "Failed to decrypt secrets file - skipping remote access configuration"
    rm -f "$DECRYPTED_FILE"
    exit 0
fi

# Source the decrypted secrets
source "$DECRYPTED_FILE"

# Install Dataplicity if token is present
if [ -n "$DATAPLICITY_TOKEN" ]; then
    echo "Installing Dataplicity..."
    curl -s "https://www.dataplicity.com/${DATAPLICITY_TOKEN}.py" | python3 \
        && echo "Dataplicity installed successfully" \
        || echo "Warning: Dataplicity installation failed"
fi

# Install SocketXP if token is present
if [ -n "$SOCKETXP_AUTH_TOKEN" ]; then
    echo "Installing SocketXP..."
    curl -fsSL https://portal.socketxp.com/download/iot/socketxp_install.sh | \
        bash -s -- -a "$SOCKETXP_AUTH_TOKEN" \
        && echo "SocketXP installed successfully" \
        || echo "Warning: SocketXP installation failed"
fi

# Clean up decrypted file immediately
shred -u "$DECRYPTED_FILE" 2>/dev/null || rm -f "$DECRYPTED_FILE"

echo "Remote access configuration complete"