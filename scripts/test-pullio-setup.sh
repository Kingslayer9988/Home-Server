#!/bin/bash

# Test script for Enhanced Pullio
# This script helps verify your setup before running the main script

echo "=== Enhanced Pullio Test Script ==="
echo

# Test 1: Check Docker installation
echo "1. Testing Docker installation..."
if command -v docker &> /dev/null; then
    echo "   ✅ Docker found: $(docker --version)"
    
    # Test Docker Compose
    if docker compose version &> /dev/null; then
        echo "   ✅ Docker Compose V2 found: $(docker compose version --short)"
        COMPOSE_TYPE="V2"
    elif command -v docker-compose &> /dev/null; then
        echo "   ✅ Docker Compose V1 found: $(docker-compose --version)"
        COMPOSE_TYPE="V1"
    else
        echo "   ❌ Docker Compose not found"
        COMPOSE_TYPE="NONE"
    fi
else
    echo "   ❌ Docker not found"
    exit 1
fi
echo

# Test 2: Check for running containers
echo "2. Testing container detection..."
containers=$(docker ps --format '{{.Names}}' 2>/dev/null | wc -l)
echo "   📊 Found $containers running containers"

labeled_containers=$(docker ps --format '{{.Names}}' --filter "label=org.hotio.pullio.update=true" 2>/dev/null | wc -l)
echo "   🏷️  Found $labeled_containers containers with pullio update labels"

if [ "$labeled_containers" -eq 0 ]; then
    echo "   ℹ️  No labeled containers found - will use custom directory mode"
fi
echo

# Test 3: Check custom directories
echo "3. Testing custom directories..."
directories=(
    "/home/kingslayer/Documents/github/Home-Server/docker/gluetun"
    "/home/kingslayer/Documents/github/Home-Server/docker/torrent-server"
    "/home/kingslayer/Documents/github/Home-Server/docker/vaultwarden"
    "/home/kingslayer/Documents/github/Home-Server/docker/photoprism"
    "/home/kingslayer/Documents/github/Home-Server/docker/omada-controller"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        if [ -f "$dir/docker-compose.yaml" ] || [ -f "$dir/docker-compose.yml" ]; then
            echo "   ✅ $dir (has compose file)"
        else
            echo "   ⚠️  $dir (no compose file found)"
        fi
    else
        echo "   ❌ $dir (directory not found)"
    fi
done
echo

# Test 4: Check dependencies
echo "4. Testing dependencies..."
deps=("curl" "jq")
for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        echo "   ✅ $dep found"
    else
        echo "   ❌ $dep not found (install with: sudo apt install $dep)"
    fi
done
echo

# Test 5: Test Telegram setup (if configured)
echo "5. Testing Telegram configuration..."
if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    echo "   📱 Telegram bot token: ${TELEGRAM_BOT_TOKEN:0:10}... (configured)"
    echo "   💬 Telegram chat ID: $TELEGRAM_CHAT_ID"
    
    echo "   🔄 Testing Telegram connection..."
    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🧪 Test message from Enhanced Pullio setup test!\"}")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo "   ✅ Telegram test message sent successfully!"
    else
        echo "   ❌ Telegram test failed. Response: $response"
    fi
else
    echo "   ℹ️  Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
    echo "   💡 You can also pass them as parameters: --telegram-token TOKEN --telegram-chat CHAT_ID"
fi
echo

# Test 6: Check script permissions
echo "6. Testing script permissions..."
script_path="/home/kingslayer/Documents/github/Home-Server/scripts/pullio-enhanced.sh"
if [ -f "$script_path" ]; then
    if [ -x "$script_path" ]; then
        echo "   ✅ Enhanced Pullio script is executable"
    else
        echo "   ⚠️  Enhanced Pullio script is not executable (run: chmod +x $script_path)"
    fi
else
    echo "   ❌ Enhanced Pullio script not found at $script_path"
fi
echo

# Summary
echo "=== Test Summary ==="
echo "Docker: $([ -n "$(command -v docker)" ] && echo "✅" || echo "❌")"
echo "Docker Compose: $([ "$COMPOSE_TYPE" != "NONE" ] && echo "✅" || echo "❌")"
echo "Containers: $containers total, $labeled_containers labeled"
echo "Dependencies: $([ -n "$(command -v curl)" ] && [ -n "$(command -v jq)" ] && echo "✅" || echo "❌")"
echo "Telegram: $([ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ] && echo "✅ Configured" || echo "ℹ️ Not configured")"
echo

if [ "$labeled_containers" -gt 0 ]; then
    echo "🚀 Ready to run Enhanced Pullio in label mode!"
else
    echo "🚀 Ready to run Enhanced Pullio in custom directory mode!"
fi

echo
echo "To run the enhanced script:"
echo "  ./pullio-enhanced.sh"
echo
echo "With Telegram notifications:"
echo "  TELEGRAM_BOT_TOKEN='your_token' TELEGRAM_CHAT_ID='your_chat_id' ./pullio-enhanced.sh"
