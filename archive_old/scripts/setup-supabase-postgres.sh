#!/bin/bash
# Supabase PostgreSQL Setup Script for Authentik
# This script helps configure Supabase as external PostgreSQL for Authentik

set -e

echo "🐘 Supabase PostgreSQL Setup for Authentik"
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${YELLOW}Supabase CLI not found. Installing...${NC}"

    # Install based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install supabase/tap/supabase
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -sL https://github.com/supabase/cli/releases/latest/download/supabase_$(uname -s)_$(uname -m).tar.gz | tar xz -C /tmp
        sudo mv /tmp/supabase /usr/local/bin/
    else
        echo -e "${RED}Unsupported OS. Please install Supabase CLI manually:${NC}"
        echo "https://github.com/supabase/cli"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Supabase CLI installed${NC}"
echo ""

# Get OCI VM IP
read -p "Enter your OCI VM public IP address: " OCI_IP
echo ""

echo "📋 Next steps:"
echo "=============="
echo ""
echo "1. Create a Supabase account (free tier):"
echo "   https://supabase.com/dashboard/sign-up"
echo ""
echo "2. Create a new project:"
echo "   - Click 'New Project'"
echo "   - Choose organization"
echo "   - Set name: 'authentik-db'"
echo "   - Choose region closest to your OCI region (e.g., Frankfurt for eu-paris-1)"
echo "   - Set password (save it!)"
echo ""
echo "3. Wait for database to be ready (~2 minutes)"
echo ""
echo "4. Get connection string:"
echo "   - Go to Project Settings → Database"
echo "   - Copy 'Connection string' (URI format)"
echo "   - It looks like: postgresql://postgres:[PASSWORD]@db.[PROJECT_REF].supabase.co:5432/postgres"
echo ""
echo "5. Configure Network Restrictions (IMPORTANT for security):"
echo "   a. Go to Project Settings → Database → Network Restrictions"
echo "   b. Click 'Add New IP Address'"
echo "   c. Add your OCI VM IP: ${OCI_IP}"
echo "   d. Remove '0.0.0.0/0' (allow all) if present"
echo "   e. Save changes"
echo ""
echo "6. Add to Doppler:"
echo "   doppler secrets set AUTHENTIK_POSTGRES_URI 'your-connection-string' -p infrastructure"
echo ""

read -p "Press Enter when you've completed step 4 (have connection string)..."
echo ""

# Test connection
read -p "Paste your Supabase connection string: " PG_URI
echo ""

echo "Testing connection to Supabase..."
if command -v psql &> /dev/null; then
    if psql "${PG_URI}" -c "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Connection successful!${NC}"
    else
        echo -e "${RED}✗ Connection failed. Check:${NC}"
        echo "  - Connection string is correct"
        echo "  - IP restrictions allow your current IP"
        echo "  - Database is ready (not in 'building' state)"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ psql not installed. Skipping connection test.${NC}"
fi

echo ""
echo "📝 Doppler Configuration"
echo "========================"
echo ""
echo "Add these secrets to Doppler (infrastructure project):"
echo ""
echo "AUTHENTIK_POSTGRES_URI: ${PG_URI}"
echo ""

# Create .env example
cat > docker/oci-core/.env.supabase.example << EOF
# Supabase PostgreSQL for Authentik
# Copy this to .env and fill in real values

AUTHENTIK_POSTGRES_URI=${PG_URI}

# Other Authentik secrets (generate these)
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60)
AUTHENTIK_BOOTSTRAP_PASSWORD=change-me-strong-password
AUTHENTIK_BOOTSTRAP_TOKEN=$(openssl rand -hex 32)
EOF

echo -e "${GREEN}✓ Created .env.supabase.example${NC}"
echo ""

echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add AUTHENTIK_POSTGRES_URI to Doppler"
echo "2. Update docker-compose.yml to use external database"
echo "3. Deploy with: gh workflow run deploy-stack.yml"
