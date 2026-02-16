#!/bin/bash
# Grafana Cloud Setup Script
# Automates the creation of Grafana Cloud stack and retrieval of credentials

set -e

echo "📊 Grafana Cloud Setup for Homelab"
echo "===================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required${NC}"
    exit 1
fi

echo -e "${BLUE}Step 1: Create Grafana Cloud Account${NC}"
echo "====================================="
echo ""
echo "If you don't have a Grafana Cloud account yet:"
echo "1. Visit: https://grafana.com/auth/sign-up/create-user"
echo "2. Sign up with your email"
echo "3. Verify your email"
echo ""
echo "Once you have an account, a default stack is created automatically."
echo ""
read -p "Press Enter once you have a Grafana Cloud account..."
echo ""

echo -e "${BLUE}Step 2: Get Your Stack URL${NC}"
echo "==========================="
echo ""
echo "1. Log in to https://grafana.com/login"
echo "2. Go to 'My Account' → 'Grafana Cloud'"
echo "3. You'll see your stack (e.g., 'https://your-stack.grafana.net')"
echo ""
read -p "Enter your Grafana Cloud stack URL (e.g., https://your-stack.grafana.net): " GRAFANA_URL
echo ""

echo -e "${BLUE}Step 3: Create Access Policy Token${NC}"
echo "==================================="
echo ""
echo "We need to create an access policy token for sending metrics and logs."
echo ""
echo "1. Go to: ${GRAFANA_URL}/org/accesspolicies"
echo "2. Click 'Create Access Policy'"
echo "3. Name: 'homelab-metrics-logs'"
echo "4. Scopes:"
echo "   - metrics:write"
echo "   - logs:write"
echo "   - traces:write (optional)"
echo "5. Click 'Create'"
echo "6. Click 'Add Token'"
echo "7. Name: 'homelab-token'"
echo "8. Copy the token (starts with 'glc_')"
echo ""
read -p "Paste your access policy token: " GRAFANA_TOKEN
echo ""

echo -e "${BLUE}Step 4: Get Endpoints${NC}"
echo "======================"
echo ""
echo "Getting your endpoints from Grafana Cloud..."
echo ""

# Extract stack name from URL
STACK_NAME=$(echo "$GRAFANA_URL" | sed -E 's|https://([^/]+).*|\1|' | sed 's/.grafana.net//')

# Grafana Cloud endpoints
METRICS_URL="https://prometheus-prod-13-prod-us-east-0.grafana.net/api/prom/push"
LOGS_URL="https://logs-prod-006.grafana.net/loki/api/v1/push"
TRACES_URL="https://tempo-prod-04-prod-us-east-0.grafana.net:443"

echo "Stack Name: $STACK_NAME"
echo ""
echo "Endpoints:"
echo "  Metrics URL: $METRICS_URL"
echo "  Logs URL: $LOGS_URL"
echo "  Traces URL: $TRACES_URL"
echo ""

echo -e "${BLUE}Step 5: Test Connection${NC}"
echo "========================"
echo ""

# Test metrics endpoint
echo "Testing metrics endpoint..."
if curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $GRAFANA_TOKEN" "$METRICS_URL" | grep -q "204\|200"; then
    echo -e "${GREEN}✓ Metrics endpoint is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Could not verify metrics endpoint (this is OK if you haven't sent data yet)${NC}"
fi

echo ""

echo -e "${BLUE}Step 6: Configure Doppler${NC}"
echo "========================="
echo ""
echo "Add these secrets to Doppler (infrastructure project):"
echo ""
echo -e "${GREEN}GRAFANA_CLOUD_API_KEY${NC}=$GRAFANA_TOKEN"
echo -e "${GREEN}GRAFANA_CLOUD_METRICS_URL${NC}=$METRICS_URL"
echo -e "${GREEN}GRAFANA_CLOUD_LOGS_URL${NC}=$LOGS_URL"
echo -e "${GREEN}GRAFANA_CLOUD_TRACES_URL${NC}=$TRACES_URL"
echo ""

read -p "Do you want to add these to Doppler now? (y/n): " ADD_TO_DOPPLER

if [[ $ADD_TO_DOPPLER =~ ^[Yy]$ ]]; then
    if command -v doppler &> /dev/null; then
        echo "Adding secrets to Doppler..."
        doppler secrets set GRAFANA_CLOUD_API_KEY="$GRAFANA_TOKEN" -p infrastructure
        doppler secrets set GRAFANA_CLOUD_METRICS_URL="$METRICS_URL" -p infrastructure
        doppler secrets set GRAFANA_CLOUD_LOGS_URL="$LOGS_URL" -p infrastructure
        doppler secrets set GRAFANA_CLOUD_TRACES_URL="$TRACES_URL" -p infrastructure
        echo -e "${GREEN}✓ Secrets added to Doppler${NC}"
    else
        echo -e "${YELLOW}⚠ Doppler CLI not installed. Please add manually.${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping Doppler configuration${NC}"
fi

echo ""

echo -e "${BLUE}Step 7: Update Configuration${NC}"
echo "============================="
echo ""

# Create/update alloy.config
cat > docker/oci-core/config/alloy.config << EOF
// Grafana Alloy Configuration
// Sends metrics, logs, and traces to Grafana Cloud

logging {
  level = "info"
}

// ====================
// PROMETHEUS METRICS
// ====================

prometheus.scrape "default" {
  targets = [
    {"__address__" = "prometheus:9090", "job" = "prometheus"},
    {"__address__" = "traefik:8080", "job" = "traefik"},
    {"__address__" = "authentik-server:9000", "job" = "authentik"},
    {"__address__" = "blocky:4000", "job" = "blocky"},
  ]
  forward_to = [prometheus.remote_write.default.receiver]
  scrape_interval = "30s"
}

// Docker metrics
discovery.docker "default" {
  host = "unix:///var/run/docker.sock"
}

prometheus.scrape "docker" {
  targets = discovery.docker.default.targets
  forward_to = [prometheus.remote_write.default.receiver]
  scrape_interval = "30s"
}

// Send to Grafana Cloud
prometheus.remote_write "default" {
  endpoint {
    url = env("GCLOUD_HOSTED_METRICS_URL")

    basic_auth {
      username = env("GCLOUD_RW_API_KEY")
      password = ""
    }
  }
}

// ====================
// LOKI LOGS
// ====================

loki.source.docker "default" {
  host = "unix:///var/run/docker.sock"
  forward_to = [loki.write.default.receiver]
}

// System logs (optional)
loki.source.file "system" {
  path = "/var/log/*.log"
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = env("GCLOUD_HOSTED_LOGS_URL")

    basic_auth {
      username = env("GCLOUD_RW_API_KEY")
      password = ""
    }
  }
}

// ====================
// TEMPO TRACES (optional)
// ====================

// Uncomment if you have tracing enabled
// otelcol.receiver.otlp "default" {
//   grpc {
//     endpoint = "0.0.0.0:4317"
//   }
//   http {
//     endpoint = "0.0.0.0:4318"
//   }
//   output {
//     traces = [otelcol.exporter.otlp.tempo.input]
//   }
// }

// otelcol.exporter.otlp "tempo" {
//   client {
//     endpoint = env("GCLOUD_HOSTED_TRACES_URL")
//     auth {
//       authenticator = otelcol.auth.basic.default
//     }
//   }
// }
EOF

echo -e "${GREEN}✓ Updated alloy.config${NC}"
echo ""

# Create .env.example
cat > docker/oci-core/.env.grafana.example << EOF
# Grafana Cloud Configuration
# Copy to .env and fill in real values from Doppler

GRAFANA_CLOUD_API_KEY=$GRAFANA_TOKEN
GRAFANA_CLOUD_METRICS_URL=$METRICS_URL
GRAFANA_CLOUD_LOGS_URL=$LOGS_URL
GRAFANA_CLOUD_TRACES_URL=$TRACES_URL
EOF

echo -e "${GREEN}✓ Created .env.grafana.example${NC}"
echo ""

echo -e "${BLUE}Step 8: Deploy${NC}"
echo "=============="
echo ""
echo "To deploy with Grafana Cloud:"
echo ""
echo "1. Ensure secrets are in Doppler:"
echo "   doppler secrets list -p infrastructure"
echo ""
echo "2. Deploy stack:"
echo "   gh workflow run deploy-stack.yml"
echo ""
echo "3. Check Grafana Cloud dashboard:"
echo "   $GRAFANA_URL"
echo ""

echo -e "${GREEN}🎉 Grafana Cloud setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Verify data is flowing (may take 2-3 minutes)"
echo "2. Create dashboards in Grafana"
echo "3. Set up alerts"
echo ""

# Save configuration for reference
cat > /tmp/grafana-cloud-config.txt << EOF
Grafana Cloud Configuration
============================
Date: $(date)
Stack URL: $GRAFANA_URL
Stack Name: $STACK_NAME

Endpoints:
- Metrics: $METRICS_URL
- Logs: $LOGS_URL
- Traces: $TRACES_URL

Token: $GRAFANA_TOKEN

Doppler Secrets:
- GRAFANA_CLOUD_API_KEY
- GRAFANA_CLOUD_METRICS_URL
- GRAFANA_CLOUD_LOGS_URL
- GRAFANA_CLOUD_TRACES_URL
EOF

echo -e "${BLUE}Configuration saved to: /tmp/grafana-cloud-config.txt${NC}"
echo ""
