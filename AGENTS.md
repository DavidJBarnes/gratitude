# Gratitude App

Daily gratitude journaling app with streak tracking.

## Architecture

- **api/**: Python FastAPI backend with JWT auth, PostgreSQL, Alembic migrations
- **ui/**: Flutter web frontend
- **nginx/**: Reverse proxy serving Flutter static files + proxying /api/ to FastAPI
- **docker-compose.yml**: Orchestrates postgres, api, nginx

## Development

### API
```bash
cd api
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # edit with your database URL
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

### UI
```bash
cd ui
flutter pub get
flutter run -d chrome --web-port 3000
```

### Full Stack (Docker)
```bash
docker compose up --build
```

## CI/CD

GitHub Actions with SSM-based deployment. Push to `main` deploys to development.
API and UI workflows trigger independently on path changes.

## Ports (Production)
- 80/443: Nginx (SSL + static UI + API proxy)
- 8000: FastAPI (internal, proxied via nginx)
- 5432: PostgreSQL (internal)
