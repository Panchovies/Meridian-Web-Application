FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml .
COPY requirements.txt .
COPY src ./src

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir .

RUN useradd --create-home --uid 1000 appuser
USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "src.app.app:app"]