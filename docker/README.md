# Home Server Docker Containers

This directory contains Docker Compose configurations for various self-hosted services that can be run on a home server.

## Repository Structure

Each container has its own directory with a dedicated `docker-compose.yaml` file. This makes it easy to:
- Use each service independently
- Customize each service without affecting others
- Keep track of changes for each service

## Available Services

| Service | Description |
|---------|-------------|
| android | Android emulation service |
| company | Company-specific services |
| gluetun | VPN client container |
| heimdall | Application dashboard |
| omada-controller | TP-Link Omada Controller |
| onedrive | OneDrive client container |
| photoprism | Photo management system |
| torrent-server | Torrent download service |
| vaultwarden | Bitwarden-compatible password manager |
| webserver | Web server with various services |
| windows | Windows emulation service |

## Environment Variables

All sensitive information (passwords, API keys, etc.) has been replaced with environment variables. Before running any service, make sure to:

1. Create a `.env` file in the service directory
2. Define all necessary environment variables in the `.env` file

Example `.env` file for the `webserver` service:

```
DB_PASSWORD=your_secure_password
MYSQL_ROOT_PASSWORD=your_root_password
SERVICE_URL=http://your-domain.com:7020
```

## Usage

To run a service:

1. Navigate to the service directory
   ```bash
   cd /path/to/Home-Server/docker/webserver
   ```

2. Start the service
   ```bash
   docker-compose up -d
   ```

3. To stop the service
   ```bash
   docker-compose down
   ```

## Data Persistence

All services are configured to use Docker volumes for data persistence. This ensures your data remains intact even if containers are removed or updated.

## Contributing

If you want to add a new service:

1. Create a new directory for the service
2. Add a `docker-compose.yaml` file
3. Use environment variables for sensitive information
4. Update the main `compose.yml` file to include the new service
5. Update this README with information about the new service
