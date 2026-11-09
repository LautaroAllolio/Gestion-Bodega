FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY db/seed/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY db/migrations ./migrations
COPY db/seed ./seed
COPY db/init_db.py ./init_db.py

CMD ["python", "init_db.py"]
