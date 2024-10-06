#!/bin/bash

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker to set up 'ship'."
  exit 1
fi

# Prompt for the project name
read -p "Enter the project name: " PROJECT_NAME

# Prompt for the Node.js version
read -p "Enter the Node.js version you want to use (e.g., 14, 16, 18): " NODE_VERSION

# Create project directory
mkdir "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create a Dockerfile
cat <<EOF > Dockerfile
# Use the specified Node.js version with Alpine
FROM node:${NODE_VERSION}-alpine

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json (if they exist)
COPY package*.json ./

# Install dependencies if package.json exists
RUN if [ -f package.json ]; then npm install; fi

# Copy the rest of the application
COPY . .

# Command to keep the container running without exposing a port initially
CMD ["tail", "-f", "/dev/null"]
EOF

echo "Dockerfile created."

# Create a docker-compose.yml file
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}_app
    volumes:
      - .:/app
    stdin_open: true
    tty: true
EOF

echo "docker-compose.yml created."

# Create a helper script for running commands inside the container
cat <<EOF > ship
#!/bin/bash

# Function to handle docker-compose commands
function docker_compose() {
  docker-compose "\$@"
}

# Check for 'up', 'down', and 'build' commands
case "\$1" in
  up)
    docker_compose up -d
    ;;
  down)
    docker_compose down
    ;;
  build)
    docker_compose build
    ;;
  *)
    # Pass any other commands to be run inside the container
    docker exec -it ${PROJECT_NAME}_app "\$@"
    ;;
esac
EOF

# Make the helper script executable
chmod +x ship

echo "Helper script 'ship' created."

# Build and start the container in detached mode
docker-compose build
docker-compose up -d

# Initialize the Node.js project inside the container
docker exec -it ${PROJECT_NAME}_app npm init -y

echo "Node.js project initialized inside the container."

echo "Project setup complete. To build and start the container, run:"
echo "  ./ship build"
echo "  ./ship up"
echo "To stop the container, run:"
echo "  ./ship down"
echo "To run other commands inside the container, use:"
echo "  ./ship <command>"

