# TASK:                     Build a production-ready Docker image for an existing app, implement security best practices, and push it to your personal Docker Hub account with versioning.

## Overview
In this project, I’ll walk you through how I Dockerized a Node.js application using security and optimization best practices. We'll go from building a simple Express API to scanning the Docker image for vulnerabilities, tagging it properly, and pushing it to Docker Hub.

This guide is beginner-friendly and explains why each step is important, just as I learned and applied it.

## Tools & Tech Used
- Node.js (Express.js)

- Docker

- Docker Hub

- Trivy (for vulnerability scanning)

- GitHub

## Step-by-Step Process
### Step 1: Set Up the Node.js App
Let’s create a simple Express app.

Create project folder:

```
mkdir node-app
cd node-app
```

Initialize Node.js project:

```
npm init -y
```

This creates your **package.json.**

<img width="712" alt="Screenshot 2025-04-19 at 07 49 32" src="https://github.com/user-attachments/assets/8ab418fe-e535-402a-8287-467ddff3dfdc" />

Install Express:

```
npm install express
```
<img width="1173" alt="Screenshot 2025-04-19 at 07 53 13" src="https://github.com/user-attachments/assets/e3c077ca-0425-4fd9-baf6-6d4f24cc297a" />


Create app.js file:

```
touch app.js
```

```
// app.js
const express = require("express");
const app = express();

app.get("/", (req, res) => {
  res.json({ message: "Hello from Segun’s Dockerized Node.js app!" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`App running on port ${PORT}`);
});
```

<img width="1167" alt="Screenshot 2025-04-19 at 07 53 50" src="https://github.com/user-attachments/assets/030fc404-1fa9-40b0-911e-73a9e42e0162" />

### Step 2: Add .dockerignore
Avoid copying unnecessary files into the Docker image.

Create a .dockerignore file:

```
touch .dockerignore
```

```
node_modules
npm-debug.log
Dockerfile
.dockerignore
.git
.gitignore
```

<img width="921" alt="Screenshot 2025-04-19 at 08 00 16" src="https://github.com/user-attachments/assets/34fe055b-fe5f-4367-8381-7fd8723ca4fb" />

### Step 3: Write a Production-Ready Dockerfile
Now let’s write a Dockerfile using best practices:

```
# Stage 1: Install dependencies
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# Copy the application source
COPY . .

# Stage 2: Create a secure and minimal image
FROM node:18-alpine

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /app .

# Set ownership and switch user
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3000
CMD ["node", "app.js"]
```

<img width="1101" alt="Screenshot 2025-04-19 at 08 01 04" src="https://github.com/user-attachments/assets/65d84c14-86ae-4474-879d-0f6ab91144a8" />

### Step 4: Build the Docker Image

```
docker build -t sheezylion/docker-node-app:v1.0.0 .
```

<img width="1376" alt="Screenshot 2025-04-19 at 08 07 24" src="https://github.com/user-attachments/assets/7e31fe23-0ef6-46c1-a321-1d385b18fccc" />

Also tag it as latest:

```
docker tag sheezylion/docker-node-app:v1.0.0 sheezylion/docker-node-app:latest
```

<img width="880" alt="Screenshot 2025-04-19 at 08 09 18" src="https://github.com/user-attachments/assets/21916cbc-80d9-4cc4-927b-7f602081b4da" />

### Step 5: Run and Test the Container

```
docker run -p 3000:3000 sheezylion/docker-node-app:v1.0.0
```

Visit http://localhost:3000 and you should see the JSON response.

<img width="1317" alt="Screenshot 2025-04-19 at 08 09 55" src="https://github.com/user-attachments/assets/71846c99-ae27-480f-a256-a558675c52a1" />

### Step 6: Scan for Vulnerabilities with Trivy
Install Trivy:

```
brew install aquasecurity/trivy/trivy    # Mac
sudo apt install trivy                   # Linux
```

<img width="1378" alt="Screenshot 2025-04-19 at 08 12 21" src="https://github.com/user-attachments/assets/3ae324b8-2a30-42b2-8c36-498e37dec7b9" />

Scan your image:

```
trivy image sheezylion/docker-node-app:v1.0.0
```

<img width="1379" alt="Screenshot 2025-04-19 at 08 14 39" src="https://github.com/user-attachments/assets/cd228e26-9f2e-42d9-af1a-b6a37389d8e4" />

I reviewed all vulnerabilities and ensured no critical ones were present. The use of Alpine and npm ci --omit=dev helped reduce attack surface.

### Step 7: Push Image to Docker Hub

```
docker push sheezylion/docker-node-app:v1.0.0
docker push sheezylion/docker-node-app:latest
```

<img width="1300" alt="Screenshot 2025-04-19 at 08 16 04" src="https://github.com/user-attachments/assets/0f94c879-8a9e-48fe-a636-8aeb1133a5de" />

<img width="1678" alt="Screenshot 2025-04-19 at 08 16 36" src="https://github.com/user-attachments/assets/974e16f2-0bba-4f65-9d0b-912c7b5c0ea9" />

<img width="1679" alt="Screenshot 2025-04-19 at 08 17 04" src="https://github.com/user-attachments/assets/0d766495-1281-40c3-bc35-f0b58c31f943" />

## Conclusion
In this project, I successfully containerized a Node.js application using Docker by implementing best practices for production-ready images. I focused on security, performance, and maintainability by:

- Creating a lightweight, multi-stage Dockerfile with a minimal base image (Alpine)

- Running the app as a non-root user to enhance security

- Adding a .dockerignore file to reduce image bloat and speed up builds

- Using version tagging (v1.0.0, latest) to ensure traceability of builds

- Scanning the image with Trivy to identify vulnerabilities and addressing them appropriately

- Publishing the final Docker image to my personal Docker Hub account

This setup demonstrates how to securely and efficiently build Docker images that are ready for deployment in real-world environments. All steps were documented in a way that beginners can easily follow, ensuring the project serves both as a learning experience and a practical DevOps portfolio piece.

