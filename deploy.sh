#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -i "$LOG_FILE") 2>&1

# -----------------------
# Helper Functions
# -----------------------
log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# -----------------------
# Cleanup Function (always safe to call)
# -----------------------
cleanup_remote() {
  log "Performing remote cleanup due to error or interruption..."
  ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<'EOF' || true
    set -e
    sudo docker ps -q | xargs -r sudo docker stop || true
    sudo docker container prune -f || true
    sudo docker network prune -f || true
    sudo rm -rf ~/app_deploy
    sudo rm -f /etc/nginx/conf.d/app.conf
    sudo nginx -t && sudo systemctl reload nginx || true
EOF
  log "Cleanup completed (safe state restored)."
}
trap 'cleanup_remote; err "Deployment failed. Check $LOG_FILE for details."; exit 1' ERR

# -----------------------
# Cleanup Mode (manual)
# -----------------------
if [[ "${1:-}" == "--cleanup" ]]; then
  read -rp "Enter Remote Server Username: " SSH_USER
  read -rp "Enter Remote Server IP Address: " SERVER_IP
  read -rp "Enter SSH Key Path: " SSH_KEY
  cleanup_remote
  exit 0
fi

# -----------------------
# Step 1: Collect User Input
# -----------------------
read -rp "Enter Git Repository URL: " GIT_URL
read -srp "Enter Personal Access Token (PAT): " GIT_PAT; echo
read -rp "Enter Branch Name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -rp "Enter Remote Server Username: " SSH_USER
read -rp "Enter Remote Server IP Address: " SERVER_IP
read -rp "Enter SSH Key Path: " SSH_KEY
read -rp "Enter Application Internal Port: " APP_PORT

# -----------------------
# Step 2: Clone Repository
# -----------------------
WORK_DIR="$HOME/deploy_workspace"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

REPO_NAME=$(basename -s .git "$GIT_URL")

if [ -d "$REPO_NAME" ]; then
  log "Repository exists. Pulling latest changes..."
  cd "$REPO_NAME"
  git pull origin "$BRANCH"
else
  log "Cloning repository..."
  git clone -b "$BRANCH" "https://${GIT_PAT}@${GIT_URL#https://}" "$REPO_NAME"
  cd "$REPO_NAME"
fi

if [ ! -f "docker-compose.yml" ] && [ ! -f "Dockerfile" ]; then
  err "No Dockerfile or docker-compose.yml found."
  exit 1
fi
log "Docker configuration verified."

# -----------------------
# Step 3: SSH & Install Dependencies
# -----------------------
log "Checking SSH connection..."
if ! ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$SSH_USER@$SERVER_IP" 'echo connected'; then
  err "SSH connection failed."
  exit 1
fi

log "Installing Docker, Docker Compose, and Nginx..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<'EOF'
  set -e
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release nginx
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || true
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  else
    sudo yum install -y docker nginx || sudo dnf install -y docker nginx
    if ! command -v docker-compose >/dev/null 2>&1; then
      sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
    fi
  fi

  sudo systemctl enable docker --now
  sudo systemctl enable nginx --now
EOF

# -----------------------
# Step 4: Transfer Project and Build
# -----------------------
log "Transferring project files..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" "mkdir -p ~/app_deploy"
rsync -avz -e "ssh -i $SSH_KEY" --exclude='.git' "$WORK_DIR/$REPO_NAME/" "$SSH_USER@$SERVER_IP:~/app_deploy/"

log "Building and deploying Docker containers..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<EOF
  set -e
  cd ~/app_deploy
  log() { echo -e "\\033[1;32m[INFO]\\033[0m \$*"; }

  # Free up port 80 if in use
  CONFLICT_PID=\$(sudo lsof -t -i:80 || true)
  if [ -n "\$CONFLICT_PID" ]; then
    log "Port 80 in use. Stopping processes..."
    sudo fuser -k 80/tcp || true
  fi

  if [ -f docker-compose.yml ]; then
    log "Using docker-compose..."
    sudo docker-compose down || true
    sudo docker-compose up -d --build
  else
    APP_IMAGE=${REPO_NAME,,}:latest
    EXISTING=\$(sudo docker ps -q --filter "ancestor=\$APP_IMAGE" || true)
    [ -n "\$EXISTING" ] && sudo docker stop \$EXISTING || true
    sudo docker build -t \$APP_IMAGE .
    sudo docker run -d --name ${REPO_NAME}_container -p 80:$APP_PORT \$APP_IMAGE
  fi
EOF

# -----------------------
# Step 5: Configure Nginx (forward traffic from port 80 to container)
# -----------------------
NGINX_CONF=$(cat <<NGX
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGX
)

log "Configuring Nginx reverse proxy..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<EOF
  set -e
  sudo mkdir -p /etc/nginx/conf.d

  # Remove default Nginx configs (Ubuntu + Amazon Linux)
  sudo rm -f /etc/nginx/conf.d/default.conf /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default || true

  # Write our clean config
  echo '$NGINX_CONF' | sudo tee /etc/nginx/conf.d/app.conf > /dev/null

  # Validate syntax before starting
  sudo nginx -t

  # Kill anything holding port 80 (usually Docker)
  sudo fuser -k 80/tcp || true

  # Clean up stale Nginx PID if present
  sudo rm -f /run/nginx.pid || true

  # Reload or start Nginx
  sudo systemctl daemon-reload || true
  sudo systemctl enable nginx --now || true
  sudo systemctl restart nginx || sudo systemctl start nginx
EOF

# -----------------------
# Step 6: Deploy Docker Container (no host port 80 binding)
# -----------------------
log "Building and deploying Docker container..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<EOF
  set -e
  cd ~/app_deploy
  log() { echo -e "\\033[1;32m[INFO]\\033[0m \$*"; }

  # Stop & remove old container
  if sudo docker ps -a --format '{{.Names}}' | grep -q '^${REPO_NAME}_container$'; then
    log "Removing existing container..."
    sudo docker stop ${REPO_NAME}_container || true
    sudo docker rm ${REPO_NAME}_container || true
  fi

  # Build Docker image
  APP_IMAGE=${REPO_NAME,,}:latest
  sudo docker build -t \$APP_IMAGE .

  # Run container (bind internally only)
  sudo docker run -d --name ${REPO_NAME}_container -p 127.0.0.1:${APP_PORT}:${APP_PORT} \$APP_IMAGE
EOF

# -----------------------
# Step 7: Validate Deployment
# -----------------------
log "Validating deployment..."
ssh -i "$SSH_KEY" "$SSH_USER@$SERVER_IP" bash -s <<'EOF'
  set -e
  sudo systemctl is-active --quiet docker && echo "Docker running"

  # Start nginx if it stopped again
  if ! sudo systemctl is-active --quiet nginx; then
    echo "Nginx not active — restarting..."
    sudo rm -f /run/nginx.pid || true
    sudo fuser -k 80/tcp || true
    sudo systemctl restart nginx || sudo systemctl start nginx
  fi

  sudo systemctl is-active --quiet nginx && echo "Nginx running"

  echo "Testing app through Nginx..."
  curl -I http://localhost || echo "  App might not be responding via Nginx"
EOF

log "Deployment completed successfully!"
log "Access your app at: http://$SERVER_IP"

trap - ERR