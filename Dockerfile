# -----------------------------------------------------------
# Stage: Build lightweight Nginx container for AKS deployment
# -----------------------------------------------------------

# Use official lightweight Nginx base image
FROM nginx:1.25-alpine

# Set working directory
WORKDIR /usr/share/nginx/html

# Copy static application files (if any)
# For now, we’ll use a simple index.html placeholder
COPY ./chart/app/ /usr/share/nginx/html/

# Expose default HTTP port
EXPOSE 80

# Run Nginx in foreground (required for container runtime)
CMD ["nginx", "-g", "daemon off;"]
