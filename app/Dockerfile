FROM python:3.12-slim

# Keep Python output unbuffered and disable .pyc files for containers.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies first to maximize Docker layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Add an unprivileged user for runtime security.
RUN addgroup --system app && adduser --system --ingroup app app

# Copy the FastAPI source code.
COPY main.py ./

USER app

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
