FROM python:3.14.3-slim

WORKDIR /app

COPY pyproject.toml .
COPY requirements.txt .
COPY src ./src

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir .

EXPOSE 5000

CMD ["python", "-m", "app.app"]