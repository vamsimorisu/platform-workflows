FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN useradd -m app
USER app
CMD ["python", "app.py"]
