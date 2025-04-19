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
