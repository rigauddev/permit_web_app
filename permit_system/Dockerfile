FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --upgrade pip && \
    pip install -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["sh", "-c", "python scripts/wait_for_db.py && if [ \"${RUN_SEED:-false}\" = \"true\" ]; then python scripts/seed.py; fi && uvicorn main:app --host 0.0.0.0 --port 8000"]
