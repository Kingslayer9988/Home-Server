# Enhanced Pullio Configuration Guide

## Overview
This enhanced version of your pullio script combines the simplicity of your working `pullio.sh` with all the advanced features of the original `pullioOG.sh`, plus Telegram bot notifications.

## Features Added
- ✅ Label-based container detection (`org.hotio.pullio.update=true`)
- ✅ Notification support (Discord, Telegram, Generic Webhooks)
- ✅ Version comparison and tracking
- ✅ Custom script execution on updates
- ✅ Registry authentication support
- ✅ Parallel processing
- ✅ Fallback to custom directory processing
- ✅ **NEW: Telegram Bot notifications**

## Setup Instructions

### 1. Telegram Bot Setup
1. Create a new bot by messaging [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` and follow the instructions
3. Save the bot token (looks like: `TOKEN`)
4. Get your chat ID:
   - Start a chat with your bot
   - Send a message to your bot
   - Visit: `https://api.telegram.org/API/getUpdates`
   - Find the `chat.id` in the response

### 2. Environment Variables
Set these environment variables or pass them as parameters:

```bash
export TELEGRAM_BOT_TOKEN="your_bot_token_here"
export TELEGRAM_CHAT_ID="your_chat_id_here"
```

### 3. Docker Compose Labels
Your containers already have the basic labels. You can enhance them with additional options:

```yaml
services:
  your_service:
    image: your/image:latest
    labels:
      # Basic update control
      - "org.hotio.pullio.update=true"           # Enable automatic updates
      - "org.hotio.pullio.notify=true"           # Enable notifications only (no auto-update)
      
      # Notification webhooks
      - "org.hotio.pullio.discord.webhook=https://discord.com/api/webhooks/..."
      - "org.hotio.pullio.generic.webhook=https://your-webhook-url.com"
      
      # Custom scripts (executed on update/notify)
      - "org.hotio.pullio.script.update=/path/to/update-script.sh"
      - "org.hotio.pullio.script.notify=/path/to/notify-script.sh"
      
      # Registry authentication (if using private registries)
      - "org.hotio.pullio.registry.authfile=/path/to/auth.json"
      
      # Author information for notifications
      - "org.hotio.pullio.author.avatar=https://example.com/avatar.png"
      - "org.hotio.pullio.author.url=https://github.com/your-repo"
```

## Usage Examples

### Basic Usage
```bash
# Run with default settings
./pullio-enhanced.sh

# Run with Telegram notifications
./pullio-enhanced.sh --telegram-token "123456789:ABC..." --telegram-chat "123456789"

# Run with debug mode
./pullio-enhanced.sh --debug

# Run with higher parallelism
./pullio-enhanced.sh --parallel 4

# Show help
./pullio-enhanced.sh --help
```

### Environment Variable Method
```bash
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export TELEGRAM_CHAT_ID="123456789"
./pullio-enhanced.sh
```

### Cron Job Setup
```bash
# Edit crontab
crontab -e

# Add entry to run every 4 hours
0 */4 * * * /home/kingslayer/Documents/github/Home-Server/scripts/pullio-enhanced.sh >/dev/null 2>&1

# Or with Telegram notifications
0 */4 * * * TELEGRAM_BOT_TOKEN="your_token" TELEGRAM_CHAT_ID="your_chat_id" /home/kingslayer/Documents/github/Home-Server/scripts/pullio-enhanced.sh >/dev/null 2>&1
```

## Notification Types

### Telegram Notifications
- 🔄 **Updated**: Container was successfully updated
- 📢 **Update Available**: New version available (notify-only mode)
- ℹ️ **Info**: General information messages

Example Telegram message:
```
🔄 Docker Container Updated

📦 Container: vaultwarden
🏷️ Image: vaultwarden/server:latest
🔄 Version: 1.28.1 → 1.29.0
⏰ Time: 2025-05-31 14:30:15
```

### Discord Notifications
Rich embeds with:
- Container name and image
- Version changes
- Image ID changes
- Timestamps
- Author information

### Generic Webhooks
JSON payload with all container information for custom integrations.

## Migration from Original Scripts

### From your current `pullio.sh`
The enhanced script maintains backward compatibility. If no containers have pullio labels, it will fall back to the custom directory processing method from your original script.

### From `pullioOG.sh`
All features are preserved and enhanced:
- All original functionality maintained
- Added Telegram support
- Improved error handling
- Better directory structure support

## Security Notes
- Store bot tokens securely (use environment variables, not hardcoded)
- Consider using Docker secrets for production environments
- Limit bot permissions to only necessary chats
- Regularly rotate bot tokens

## Troubleshooting

### Common Issues
1. **No notifications received**: Check bot token and chat ID
2. **Containers not detected**: Ensure labels are properly set
3. **Permission errors**: Make sure script is executable (`chmod +x`)
4. **Docker not found**: Ensure Docker is installed and in PATH

### Debug Mode
Run with `--debug` to see detailed output:
```bash
./pullio-enhanced.sh --debug
```

### Test Telegram Setup
You can test your Telegram setup with:
```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{"chat_id": "<YOUR_CHAT_ID>", "text": "Test message from Enhanced Pullio!"}'
```
