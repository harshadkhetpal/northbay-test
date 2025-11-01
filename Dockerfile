# Multi-stage build for Dubai Real Estate ML Service
FROM python:3.11-slim as base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY chart/app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY chart/app/ ./app/

# Create models directory
RUN mkdir -p /app/models

# Generate and save a trained model (for demo purposes)
# In production, download from Azure Blob Storage or mount from Key Vault
RUN python -c "import sys; sys.path.insert(0, '/app'); from app.train_model import train_model; train_model()"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD curl -f http://localhost:8000/health || exit 1

# Expose FastAPI port
EXPOSE 8000

# Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Run FastAPI server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
