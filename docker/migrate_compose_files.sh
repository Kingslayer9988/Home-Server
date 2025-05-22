#!/bin/bash

# Target directory for the new structure
TARGET_DIR="/home/kingslayer/Documents/github/Home-Server/docker"

# Source directory where existing compose files are located
SOURCE_DIR="/home/kingslayer/docker_compose"

# Function to sanitize docker-compose files
sanitize_compose_file() {
    local file="$1"
    local output_file="$2"
    
    # Create directory for the container if it doesn't exist
    local container_dir=$(dirname "$output_file")
    mkdir -p "$container_dir"
    
    # Copy the file first
    cp "$file" "$output_file"
    
    # Replace passwords with placeholders
    sed -i 's/password: .*$/password: ${DB_PASSWORD:-changeme}/g' "$output_file"
    sed -i 's/MYSQL_ROOT_PASSWORD: .*$/MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-changeme}/g' "$output_file"
    sed -i 's/MYSQL_PASSWORD: .*$/MYSQL_PASSWORD: ${MYSQL_PASSWORD:-changeme}/g' "$output_file"
    sed -i 's/POSTGRES_PASSWORD: .*$/POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}/g' "$output_file"
    
    # Replace API keys with placeholders
    sed -i 's/apikey: .*$/apikey: ${API_KEY:-your_api_key_here}/g' "$output_file"
    sed -i 's/API_KEY: .*$/API_KEY: ${API_KEY:-your_api_key_here}/g' "$output_file"
    
    # Replace other potentially sensitive information
    sed -i 's/token: .*$/token: ${TOKEN:-your_token_here}/g' "$output_file"
    sed -i 's/secret: .*$/secret: ${SECRET:-your_secret_here}/g' "$output_file"
    
    # Replace specific URLs with placeholders
    sed -i 's|url: http://localhost:[0-9]*|url: ${SERVICE_URL:-http://localhost:PORT}|g' "$output_file"
    
    echo "Sanitized $file to $output_file"
}

# Find all docker-compose files
find "$SOURCE_DIR" -name "docker-compose.yaml" -o -name "docker-compose.yml" | while read compose_file; do
    # Extract the container/service name from the directory path
    service_dir=$(basename $(dirname "$compose_file"))
    
    # Skip nested docker_build directories which might contain multiple services
    if [[ "$compose_file" == *"docker_build"* ]]; then
        echo "Skipping $compose_file (docker_build directory)"
        continue
    fi
    
    # Create output path
    output_dir="$TARGET_DIR/$service_dir"
    output_file="$output_dir/docker-compose.yaml"
    
    # Sanitize and copy the file
    sanitize_compose_file "$compose_file" "$output_file"
done

echo "Migration complete! All compose files have been copied and sanitized."
