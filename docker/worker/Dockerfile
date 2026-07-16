FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt \
    && useradd -m appuser

COPY worker.py .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 5001

CMD ["python", "worker.py"]
