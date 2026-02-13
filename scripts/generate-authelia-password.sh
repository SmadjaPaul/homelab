#!/bin/bash
# Generate Authelia password hash
# Usage: ./scripts/generate-authelia-password.sh "your-password"

if [ -z "$1" ]; then
    echo "Usage: $0 <password>"
    echo "Example: $0 'MySecurePassword123!'"
    exit 1
fi

PASSWORD="$1"

echo "Generating Authelia password hash..."
echo ""

# Run authelia container to generate hash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password "$PASSWORD"

echo ""
echo "Copy the hash above and update config/authelia/users_database.yml"
echo ""
echo "To generate another password, run:"
echo "  ./scripts/generate-authelia-password.sh 'your-password'"
