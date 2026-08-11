FROM python:3.14.3-slim

WORKDIR /app

COPY pyproject.toml .
COPY requirements.txt .
COPY src ./src

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir .

RUN useradd --create-home --uid 1000 appuser
USER appuser

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "src.app.app:app"]