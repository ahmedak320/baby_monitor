FROM python:3.12-slim

# Install system dependencies for OpenCV, ffmpeg, and audio processing
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN useradd --create-home --shell /bin/bash worker && \
    chown -R worker:worker /app
USER worker

CMD ["python", "main.py"]
