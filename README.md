# Automated Deployment Bash script

## Project Overview
This project automates the deployment of a Dockerized web application using a single Bash script (deploy.sh).
The script installs and configures all necessary dependencies (Docker, Docker Compose, and Nginx), deploys your application, and sets up an Nginx reverse proxy to serve traffic on port 80.

It is fully idempotent, cross-platform, and includes logging with timestamps for traceability and debugging.

### **Supported Environments**

The script works seamlessly across:

- Ubuntu (20.04 / 22.04 / 24.04)

- Amazon Linux 2 / 2023

- Debian / RHEL-based distributions

It automatically detects and uses the correct package manager (apt-get, yum, or dnf).

### **Features**

Collects user input interactively:

- Git repository URL

- Personal Access Token (hidden input for security)

- Branch name

- Remote SSH username and IP address

- Path to SSH key
  
- Internal container port

<img width="736" height="689" alt="Screenshot 2025-10-22 at 22 15 01" src="https://github.com/user-attachments/assets/3178cba2-5345-4f32-b726-d598b01ebf8c" />

Once all the above details is confirmed, the script:

- Installs Docker, Docker Compose, and Nginx (if missing)

- Clones or updates the source code repository

- Builds and deploys the application via Docker

- Configures Nginx reverse proxy to forward traffic to port 80

- Handles cleanup automatically if any error occurs

- Ensures idempotency — safe to re-run anytime

Logs all actions with timestamps to a file like:

```
deploy_20251022_220844.log
```
<img width="648" height="499" alt="Screenshot 2025-10-22 at 22 16 19" src="https://github.com/user-attachments/assets/59fc838c-466b-45f6-a8f5-f6b92e9e1ef9" />


### **Step-by-Step Usage Guide**

- Clone or copy the deploy.sh script to your local machine.

- Make the script executable:

```
chmod +x deploy.sh
```

- Run the script:

```
./deploy.sh
```

**When prompted, enter:**

- Git repository URL (e.g., https://github.com/username/repo.git)

- Personal Access Token (hidden input)

- Branch name (default is main)

- SSH username (e.g., ubuntu or ec2-user)

- Server IP address

- SSH private key path (e.g., ~/.ssh/id_rsa)

- Application internal port (e.g., 3000)

**The script will:**

- Connect to your server via SSH

- Install or verify Docker and Nginx

- Build and run the Docker container

- Configure Nginx to forward port 80 → internal app port

- Validate the deployment automatically

**After completion, check your app by visiting:**

```
http://<YOUR_SERVER_IP>
```

<img width="1190" height="551" alt="Screenshot 2025-10-22 at 22 17 18" src="https://github.com/user-attachments/assets/cc2630c5-6f72-40fb-b473-d94efb7b9707" />

**Cleanup Instructions**

If you need to remove all containers, images, and configurations:

```
./deploy.sh --cleanup
```

<img width="702" height="472" alt="Screenshot 2025-10-22 at 22 21 16" src="https://github.com/user-attachments/assets/1e59a070-e0ed-4793-8a0b-d05c8a43a855" />


**This will:**

- Stop and remove all running containers

- Clean Docker networks and images

- Remove Nginx configurations

- Restore the server to a safe, clean state

### **Idempotency**

The script can be run multiple times without causing conflicts:

- Existing containers are safely stopped and replaced.

- Dependencies are checked before installation.

- Nginx configurations are overwritten cleanly.

- If something fails, automatic cleanup restores a stable state.

The deployment.sh script is designed for environments where repeatable and predictable deployments are required without relying on external tools like Ansible or Terraform.

