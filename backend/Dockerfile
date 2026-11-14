# The Sonder API as Railway (or any Docker host) runs it.
# Railway builds this automatically when the service's Root Directory is set to /backend.
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app ./app
COPY db ./db
# Only the demo photos; real photos go to Cloudflare R2.
COPY uploads ./uploads

# Railway sets PORT. --proxy-headers so the app sees the real https:// scheme behind Railway's proxy.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips='*'"]
