#!/bin/bash

compose_up_wrapper() {
    # Define directories containing Docker Compose files
    directories=(
        "/home/kingslayer/docker_compose/gluetun"
        "/home/kingslayer/docker_compose/torrent-server"
        "/home/kingslayer/docker_compose/vaultwarden"
        "/home/kingslayer/docker_compose/photoprism"
        "/home/kingslayer/docker_compose/omada-controller"
    )

    # Iterate over each directory
    for dir in "${directories[@]}"; do
        echo "Updating containers in directory: $dir"
        
        # Change to the specified directory
        cd "$dir" || {
            echo "Failed to change directory to $dir"
            continue
        }

        # Bring down existing containers
        docker compose down || {
            echo "Failed to bring down containers in $dir"
            continue
        }
        
        # Pull the latest images
        docker compose pull || {
            echo "Failed to pull images in $dir"
            continue
        }
        
        # Bring up containers in detached mode
        docker compose up -d || {
            echo "Failed to bring up containers in $dir"
            continue
        }
        
        echo "Containers updated successfully in $dir"
    done
}

# Call the function to update containers
compose_up_wrapper