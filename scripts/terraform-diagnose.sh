#!/bin/bash

# Terraform Diagnostics and Fix Script

echo "════════════════════════════════════════"
echo "Terraform Environment Diagnostics"
echo "════════════════════════════════════════"
echo ""

# Check Terraform version
echo "1. Terraform Version:"
terraform version
echo ""

# Check if LocalStack is running
echo "2. LocalStack Status:"
if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo "✓ LocalStack is running"
    echo "Services:"
    curl -s http://localhost:4566/_localstack/health | python3 -m json.tool 2>/dev/null || echo "Could not parse health"
else
    echo "✗ LocalStack is NOT running"
fi
echo ""

# Check environment variables
echo "3. Environment Variables:"
echo "   AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-not set}"
echo "   AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-not set}"
echo "   AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-not set}"
echo ""

# Check plugin cache
echo "4. Terraform Plugin Cache:"
if [ -d "$HOME/.terraform.d/plugins" ]; then
    echo "   Cache exists at: $HOME/.terraform.d/plugins"
    echo "   Size: $(du -sh $HOME/.terraform.d/plugins 2>/dev/null | cut -f1)"
else
    echo "   No plugin cache found"
fi
echo ""

# Check current directory setup
echo "5. Current Directory Status:"
cd "$(dirname "$0")/../terraform/localstack"
if [ -d ".terraform" ]; then
    echo "   .terraform exists"
    if [ -d ".terraform/providers" ]; then
        echo "   Providers downloaded: $(ls .terraform/providers 2>/dev/null | wc -l) versions"
    fi
else
    echo "   .terraform does NOT exist (need to run init)"
fi
echo ""

echo "════════════════════════════════════════"
echo "Recommended Fix Based on Issue"
echo "════════════════════════════════════════"
echo ""
echo "The 'timeout while waiting for plugin to start' error usually means:"
echo ""
echo "Option A: Plugin binary is corrupted or incompatible"
echo "  Fix: rm -rf .terraform && terraform init -upgrade"
echo ""
echo "Option B: Terraform version incompatibility"
echo "  Fix: Use Terraform 1.5.x - 1.6.x (not 1.7+)"
echo ""
echo "Option C: macOS Gatekeeper blocking plugin"
echo "  Fix: Allow plugin in System Settings > Security"
echo ""
echo "Option D: Provider trying to validate against real AWS"
echo "  Fix: Already done - we skip validation in providers.tf"
echo ""

# Check Terraform version compatibility
TF_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
echo "Your Terraform version: $TF_VERSION"
echo ""

if [[ "$TF_VERSION" > "1.7" ]]; then
    echo "⚠️  WARNING: Terraform 1.7+ has known issues with some providers"
    echo "   Consider downgrading to 1.6.x: brew install terraform@1.6"
fi
echo ""

echo "════════════════════════════════════════"
echo "Automated Fixes Available"
echo "════════════════════════════════════════"
echo ""
echo "Run one of these:"
echo "  ./scripts/terraform-reset.sh    # Complete reset and reinit"
echo "  make fresh-start                # Reset everything including LocalStack"
echo ""
