#!/bin/bash

# Enhanced Pullio Script with Telegram Support
# Based on hotio/pullio with custom directory support and Telegram notifications

COMPOSE_BINARY="${COMPOSE_BINARY:-$(which 'docker-compose')}"
DOCKER_BINARY="${DOCKER_BINARY:-$(which 'docker')}"
CACHE_LOCATION=/tmp
TAG=""
DEBUG=""
CURRENT_VERSION=0.0.8
LATEST_VERSION=$(curl -fsSL "https://api.github.com/repos/hotio/pullio/releases" 2>/dev/null | jq -r .[0].tag_name 2>/dev/null || echo "unknown")
PARALLEL=1
COMPOSE_TYPE="NONE"

# Telegram configuration - set these environment variables or uncomment and set values
# TELEGRAM_BOT_TOKEN="your_bot_token_here"
# TELEGRAM_CHAT_ID="your_chat_id_here"

# Define directories containing Docker Compose files
CUSTOM_DIRECTORIES=(
    "/home/kingslayer/Documents/github/Home-Server/docker/gluetun"
    "/home/kingslayer/Documents/github/Home-Server/docker/torrent-server"
    "/home/kingslayer/Documents/github/Home-Server/docker/vaultwarden"
    "/home/kingslayer/Documents/github/Home-Server/docker/photoprism"
    "/home/kingslayer/Documents/github/Home-Server/docker/omada-controller"
)

# Check for Docker Compose version
if [[ -n "${COMPOSE_BINARY}" ]]; then
    COMPOSE_TYPE="V1"
elif [[ -n "${DOCKER_BINARY}" ]] && docker compose version &>/dev/null; then
    COMPOSE_TYPE="V2"
fi

# Parse command line arguments
while [ "$1" != "" ]; do
    PARAM=$(printf "%s\n" $1 | awk -F= '{print $1}')
    VALUE=$(printf "%s\n" $1 | sed 's/^[^=]*=//g')
    if [[ $VALUE == "$PARAM" ]]; then
        shift
        VALUE=$1
    fi
    case $PARAM in
    --tag)
        [[ -n $VALUE ]] && [[ $VALUE != "--"* ]] && TAG=".$VALUE"
        ;;
    --debug)
        [[ $VALUE != "--"* ]] && DEBUG="${VALUE:-debug}"
        ;;
    --parallel)
        [[ $VALUE =~ ^[0-9]+$ ]] && PARALLEL=$VALUE
        ;;
    --telegram-token)
        [[ -n $VALUE ]] && [[ $VALUE != "--"* ]] && TELEGRAM_BOT_TOKEN="$VALUE"
        ;;
    --telegram-chat)
        [[ -n $VALUE ]] && [[ $VALUE != "--"* ]] && TELEGRAM_CHAT_ID="$VALUE"
        ;;
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tag TAG                Set pullio tag (default: empty)"
        echo "  --debug [VALUE]          Enable debug mode"
        echo "  --parallel NUM           Set parallelism level (default: 1)"
        echo "  --telegram-token TOKEN   Set Telegram bot token"
        echo "  --telegram-chat ID       Set Telegram chat ID"
        echo "  --help                   Show this help"
        exit 0
        ;;
    esac
    shift
done

echo "Running Enhanced Pullio with \"DEBUG=$DEBUG\", \"TAG=$TAG\", and \"PARALLEL=$PARALLEL\"."
echo "Current version: ${CURRENT_VERSION}"
echo "Latest version: ${LATEST_VERSION}"

# Setup environment variables
setup_environment() {
    export COMPOSE_BINARY DOCKER_BINARY CACHE_LOCATION TAG DEBUG COMPOSE_TYPE
    export TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID

    if [ "$PARALLEL" -gt 1 ]; then
        export -f process_container compose_pull_wrapper compose_up_wrapper
        export -f send_telegram_notification send_discord_notification send_generic_webhook export_env_vars
        export sum
    fi
}

# Docker Compose pull wrapper
compose_pull_wrapper() {
    cd "$1" || exit 1
    case $COMPOSE_TYPE in
    "V1")
        "${COMPOSE_BINARY}" pull "$2"
        ;;
    "V2")
        "${DOCKER_BINARY}" compose pull "$2"
        ;;
    "NONE")
        if [[ -n "${DOCKER_BINARY}" ]]; then
            "${DOCKER_BINARY}" run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$1:$1" -w="$1" linuxserver/docker-compose pull "$2"
        else
            echo "Error: Neither Docker Compose nor Docker binary is available. Cannot pull." >&2
            return 1
        fi
        ;;
    esac
}

# Docker Compose up wrapper
compose_up_wrapper() {
    cd "$1" || exit 1
    case $COMPOSE_TYPE in
    "V1")
        "${COMPOSE_BINARY}" up -d --always-recreate-deps "$2"
        ;;
    "V2")
        "${DOCKER_BINARY}" compose up -d --always-recreate-deps "$2"
        ;;
    "NONE")
        if [[ -n "${DOCKER_BINARY}" ]]; then
            "${DOCKER_BINARY}" run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "$1:$1" -w="$1" linuxserver/docker-compose up -d --always-recreate-deps "$2"
        else
            echo "Error: Neither Docker Compose nor Docker binary is available. Cannot bring up services." >&2
            return 1
        fi
        ;;
    esac
}

# Send Telegram notification
send_telegram_notification() {
    local message="$1"
    local container_name="$2"
    local image_name="$5"
    local old_version="$3"
    local new_version="$4"
    local status_type="$11"
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi

    local emoji=""
    case "$status_type" in
        "updated") emoji="🔄" ;;
        "update_available") emoji="📢" ;;
        *) emoji="ℹ️" ;;
    esac

    local telegram_message="${emoji} *Docker Container ${status_type^}*

📦 *Container:* \`${container_name}\`
🏷️ *Image:* \`${image_name}\`"

    if [[ -n "$old_version" ]] && [[ -n "$new_version" ]] && [[ "$old_version" != "$new_version" ]]; then
        telegram_message+="\n🔄 *Version:* \`${old_version}\` → \`${new_version}\`"
    fi

    telegram_message+="\n⏰ *Time:* $(date '+%Y-%m-%d %H:%M:%S')"

    local json_payload="{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"text\": \"${telegram_message}\",
        \"parse_mode\": \"Markdown\",
        \"disable_web_page_preview\": true
    }"

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "${json_payload}" > /dev/null 2>&1
}

# Send Discord notification (from original script)
send_discord_notification() {
    if [[ "${LATEST_VERSION}" != "${CURRENT_VERSION}" ]]; then
        footer_text="Powered by Enhanced Pullio (update available)"
    else
        footer_text="Powered by Enhanced Pullio"
    fi
    extra=""
    if [[ -n $3 ]] && [[ -n $4 ]] && [[ -n $7 ]] && [[ -n $8 ]]; then
        v_ind=">" && [[ ${3} == "${4}" ]] && v_ind="="
        r_ind=">" && [[ ${7} == "${8}" ]] && r_ind="="
        extra=',
            {
            "name": "Version",
            "value": "```\n'${3}'\n ='$v_ind' '${4}'```"
            },
            {
            "name": "Revision (Git SHA)",
            "value": "```\n'${7:0:6}'\n ='$r_ind' '${8:0:6}'```"
            }'
    fi
    d_ind=">" && [[ ${9} == "${10}" ]] && d_ind="="
    author_url="${12}" && [[ -z ${12} ]] && author_url="https://github.com/hotio/pullio/raw/master/pullio.png"
    json='{
    "embeds": [
        {
        "description": "'${1}'",
        "color": '${11:-768753}',
        "fields": [
            {
            "name": "Image",
            "value": "```'${5}'```"
            },
            {
            "name": "Image ID",
            "value": "```\n'${9:0:11}'\n ='$d_ind' '${10:0:11}'```"
            }'$extra'
        ],
        "author": {
            "name": "'${2}'",
            "url": "'${13}'",
            "icon_url": "'${author_url}'"
        },
        "footer": {
            "text": "'${footer_text}'"
        },
        "timestamp": "'$(date -u +'%FT%T.%3NZ')'"
        }
    ],
    "username": "Enhanced Pullio",
    "avatar_url": "https://github.com/hotio/pullio/raw/master/pullio.png"
    }'
    curl -fsSL -H "User-Agent: Enhanced-Pullio" -H "Content-Type: application/json" -d "${json}" "${6}"
}

# Send generic webhook (from original script)
send_generic_webhook() {
    json='{
    "container": "'${2}'",
    "image": "'${5}'",
    "avatar": "'${11}'",
    "old_image_id": "'${9}'",
    "new_image_id": "'${10}'",
    "old_version": "'${3}'",
    "new_version": "'${4}'",
    "old_revision": "'${7}'",
    "new_revision": "'${8}'",
    "type": "'${1}'",
    "url": "'${12}'",
    "timestamp": "'$(date -u +'%FT%T.%3NZ')'"
    }'
    curl -fsSL -H "User-Agent: Enhanced-Pullio" -H "Content-Type: application/json" -d "${json}" "${6}"
}

# Export environment variables for scripts
export_env_vars() {
    export PULLIO_CONTAINER=${1}
    export PULLIO_IMAGE=${2}
    export PULLIO_AVATAR=${3}
    export PULLIO_OLD_IMAGE_ID=${4}
    export PULLIO_NEW_IMAGE_ID=${5}
    export PULLIO_OLD_VERSION=${6}
    export PULLIO_NEW_VERSION=${7}
    export PULLIO_OLD_REVISION=${8}
    export PULLIO_NEW_REVISION=${9}
    export PULLIO_COMPOSE_SERVICE=${10}
    export PULLIO_COMPOSE_WORKDIR=${11}
    export PULLIO_AUTHOR_URL=${13}
}

# Process individual container
process_container() {
    local container_name="$1"
    echo "$container_name: Checking..."

    image_name=$("${DOCKER_BINARY}" inspect --format='{{.Config.Image}}' "$container_name" 2>/dev/null)
    if [[ -z "$image_name" ]]; then
        echo "$container_name: Container not found or not running"
        return 1
    fi

    container_image_digest=$("${DOCKER_BINARY}" inspect --format='{{.Image}}' "$container_name")
    docker_compose_service=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "com.docker.compose.service" }}' "$container_name")
    docker_compose_version=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "com.docker.compose.version" }}' "$container_name")
    docker_compose_workdir=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "$container_name")

    old_opencontainers_image_version=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.opencontainers.image.version" }}' "$container_name")
    old_opencontainers_image_revision=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$container_name")

    pullio_update=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.update" }}' "$container_name")
    pullio_notify=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.notify" }}' "$container_name")
    pullio_discord_webhook=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.discord.webhook" }}' "$container_name")
    pullio_generic_webhook=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.generic.webhook" }}' "$container_name")
    pullio_script_update=($("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.script.update" }}' "$container_name"))
    pullio_script_notify=($("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.script.notify" }}' "$container_name"))
    pullio_registry_authfile=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.registry.authfile" }}' "$container_name")
    pullio_author_avatar=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.author.avatar" }}' "$container_name")
    pullio_author_url=$("${DOCKER_BINARY}" inspect --format='{{ index .Config.Labels "org.hotio.pullio'"${TAG}"'.author.url" }}' "$container_name")

    if [[ (-n $docker_compose_version) && ($pullio_update == true || $pullio_notify == true) ]]; then
        # Handle registry authentication if specified
        if [[ -f $pullio_registry_authfile ]]; then
            jq -r .password <"$pullio_registry_authfile" | "${DOCKER_BINARY}" login --username "$(jq -r .username <"$pullio_registry_authfile")" --password-stdin "$(jq -r .registry <"$pullio_registry_authfile")"
        fi

        echo "$container_name: Pulling image..."
        if ! compose_pull_wrapper "$docker_compose_workdir" "${docker_compose_service}"; then
            echo "$container_name: Pulling failed!"
            return 1
        fi

        image_digest=$("${DOCKER_BINARY}" image inspect --format='{{.Id}}' "${image_name}" 2>/dev/null)
        new_opencontainers_image_version=$("${DOCKER_BINARY}" image inspect --format='{{ index .Config.Labels "org.opencontainers.image.version" }}' "$image_name" 2>/dev/null)
        new_opencontainers_image_revision=$("${DOCKER_BINARY}" image inspect --format='{{ index .Config.Labels "org.opencontainers.image.revision" }}' "$image_name" 2>/dev/null)

        status="Update available for container"
        status_generic="update_available"
        color=16776960

        if [[ "${image_digest}" != "$container_image_digest" ]]; then
            if [[ $pullio_update == true ]]; then
                echo "$container_name: Updating container..."
                if compose_up_wrapper "$docker_compose_workdir" "${docker_compose_service}"; then
                    echo "$container_name: Container updated successfully"
                    status="Container has been updated successfully"
                    status_generic="updated"
                    color=65280
                    rm -f "${CACHE_LOCATION}/${sum}-${container_name}.notified"
                else
                    echo "$container_name: Update failed!"
                    status="Container update failed"
                    status_generic="update_failed"
                    color=16711680
                fi
            fi

            if [[ $pullio_notify == true ]] || [[ $pullio_update == true ]]; then
                # Send notifications
                send_telegram_notification "$status" "$container_name" "$old_opencontainers_image_version" "$new_opencontainers_image_version" "$image_name" "" "" "" "" "$container_image_digest" "$status_generic"
                
                if [[ -n $pullio_discord_webhook ]]; then
                    send_discord_notification "$status" "$container_name" "$old_opencontainers_image_version" "$new_opencontainers_image_version" "$image_name" "$pullio_discord_webhook" "$old_opencontainers_image_revision" "$new_opencontainers_image_revision" "$container_image_digest" "$image_digest" "$color" "$pullio_author_avatar" "$pullio_author_url"
                fi

                if [[ -n $pullio_generic_webhook ]]; then
                    send_generic_webhook "$status_generic" "$container_name" "$old_opencontainers_image_version" "$new_opencontainers_image_version" "$image_name" "$pullio_generic_webhook" "$old_opencontainers_image_revision" "$new_opencontainers_image_revision" "$container_image_digest" "$image_digest" "$pullio_author_avatar" "$pullio_author_url"
                fi

                # Execute custom scripts
                if [[ -n ${pullio_script_update[0]} ]] && [[ $pullio_update == true ]]; then
                    export_env_vars "$container_name" "$image_name" "$pullio_author_avatar" "$container_image_digest" "$image_digest" "$old_opencontainers_image_version" "$new_opencontainers_image_version" "$old_opencontainers_image_revision" "$new_opencontainers_image_revision" "$docker_compose_service" "$docker_compose_workdir" "$status_generic" "$pullio_author_url"
                    eval "${pullio_script_update[@]}"
                fi

                if [[ -n ${pullio_script_notify[0]} ]]; then
                    export_env_vars "$container_name" "$image_name" "$pullio_author_avatar" "$container_image_digest" "$image_digest" "$old_opencontainers_image_version" "$new_opencontainers_image_version" "$old_opencontainers_image_revision" "$new_opencontainers_image_revision" "$docker_compose_service" "$docker_compose_workdir" "$status_generic" "$pullio_author_url"
                    eval "${pullio_script_notify[@]}"
                fi
            fi
        else
            echo "$container_name: No updates available"
        fi
    else
        echo "$container_name: Skipping (no pullio labels or not a compose container)"
    fi
}

# Custom directory processing function (legacy support)
process_custom_directories() {
    echo "Processing custom directories (legacy mode)..."
    for dir in "${CUSTOM_DIRECTORIES[@]}"; do
        if [[ ! -d "$dir" ]]; then
            echo "Directory not found: $dir"
            continue
        fi

        echo "Updating containers in directory: $dir"
        cd "$dir" || {
            echo "Failed to change directory to $dir"
            continue
        }

        # Bring down existing containers
        case $COMPOSE_TYPE in
        "V1")
            "${COMPOSE_BINARY}" down || {
                echo "Failed to bring down containers in $dir"
                continue
            }
            "${COMPOSE_BINARY}" pull || {
                echo "Failed to pull images in $dir"
                continue
            }
            "${COMPOSE_BINARY}" up -d || {
                echo "Failed to bring up containers in $dir"
                continue
            }
            ;;
        "V2")
            "${DOCKER_BINARY}" compose down || {
                echo "Failed to bring down containers in $dir"
                continue
            }
            "${DOCKER_BINARY}" compose pull || {
                echo "Failed to pull images in $dir"
                continue
            }
            "${DOCKER_BINARY}" compose up -d || {
                echo "Failed to bring up containers in $dir"
                continue
            }
            ;;
        *)
            echo "No Docker Compose available in $dir"
            continue
            ;;
        esac
        
        echo "Containers updated successfully in $dir"
    done
}

# Main execution
main() {
    # Respect ctrl+c
    trap 'exit 130' INT

    # Setup the environment
    sum="$(sha1sum "$0" | awk '{print $1}')"
    setup_environment

    # Get running containers with pullio labels
    declare -a containers
    readarray -t containers < <("${DOCKER_BINARY}" ps --format '{{.Names}}' --filter "label=org.hotio.pullio${TAG}.update=true" 2>/dev/null | sort -k1)
    
    # If no labeled containers found, fall back to custom directories
    if [[ ${#containers[@]} -eq 0 ]]; then
        echo "No containers found with pullio labels, falling back to custom directory processing..."
        process_custom_directories
    else
        echo "Processing ${#containers[@]} labeled containers with parallelism of $PARALLEL"
        
        if [ "$PARALLEL" -gt 1 ]; then
            printf '%s\n' "${containers[@]}" | xargs -P "$PARALLEL" -I {} bash -c 'process_container "$@"' _ {}
        else
            for container_name in "${containers[@]}"; do
                process_container "$container_name"
            done
        fi
    fi

    echo "Pruning docker images..."
    "${DOCKER_BINARY}" image prune --force

    echo "Enhanced Pullio completed!"
}

# Run main function
main "$@"
