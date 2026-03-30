# Task Manager API

A production-ready RESTful API built with Ruby on Rails for managing tasks with user authentication, background job processing, and full Docker support.

## Tech Stack

- **Ruby** 3.2.4 / **Rails** 8.1 (API-only)
- **PostgreSQL** 16 — primary database
- **Redis** 7 — caching & background job backend
- **Sidekiq** — background job processing with cron scheduling
- **Puma** — web server
- **JWT** — token-based authentication
- **Rack::Attack** — API rate limiting
- **Rswag** — Swagger/OpenAPI documentation
- **RSpec** — test suite with SimpleCov coverage
- **Docker & Docker Compose** — containerized deployment

## Features

- User registration and JWT authentication
- Full CRUD for tasks (scoped per user)
- Task filtering by status, priority, and due date range
- Title search (case-insensitive)
- Sorting by created_at, due_date, or priority
- Pagination via Kaminari
- Background job processing (Sidekiq + Redis)
- Scheduled task cleanup job (daily via Sidekiq-Cron)
- Task notification emails on create/complete
- API rate limiting (Rack::Attack)
- Security headers middleware
- Health check endpoint with service status
- Swagger API documentation

---

## Getting Started

### Prerequisites

- Ruby 3.2.4
- PostgreSQL
- Redis
- Bundler

### Local Setup

```bash
# Clone the repository
git clone <repo-url> && cd task_manager_api

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate

# Start Redis (in a separate terminal)
redis-server

# Start Sidekiq (in a separate terminal)
bundle exec sidekiq -C config/sidekiq.yml

# Start the server
rails server
```

The API will be available at `http://localhost:3000`.

---

## Docker Setup

### Prerequisites

- Docker
- Docker Compose

### Quick Start

```bash
# Copy environment file and configure
cp .env.example .env
# Edit .env with your values (RAILS_MASTER_KEY, SECRET_KEY_BASE, etc.)

# Build and start all services
docker-compose up --build

# In another terminal, verify it's running
curl http://localhost:3000/health
```

### Services

| Service    | Description              | Port |
|------------|--------------------------|------|
| **web**    | Rails API server         | 3000 |
| **sidekiq**| Background job processor | —    |
| **postgres**| PostgreSQL database     | 5432 |
| **redis**  | Redis cache/queue store  | 6379 |

### Docker Commands

```bash
# Start services in background
docker-compose up -d

# View logs
docker-compose logs -f web

# Run Rails console
docker-compose exec web ./bin/rails console

# Run migrations
docker-compose exec web ./bin/rails db:migrate

# Stop services
docker-compose down

# Stop and remove volumes (resets database)
docker-compose down -v
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RAILS_MASTER_KEY` | Rails master key for credentials | — |
| `SECRET_KEY_BASE` | Secret key for sessions | — |
| `DATABASE_URL` | PostgreSQL connection URL | set by compose |
| `REDIS_URL` | Redis connection URL | `redis://redis:6379/0` |
| `RAILS_MAX_THREADS` | Max threads per Puma worker | `5` |
| `WEB_CONCURRENCY` | Number of Puma workers | `2` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `password` |
| `SIDEKIQ_USERNAME` | Sidekiq dashboard username | `admin` |
| `SIDEKIQ_PASSWORD` | Sidekiq dashboard password | `password` |
| `CORS_ORIGINS` | Comma-separated allowed origins | `http://localhost:3001` |
| `SMTP_ADDRESS` | SMTP server address | `smtp.example.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USERNAME` | SMTP username | — |
| `SMTP_PASSWORD` | SMTP password | — |

---

## API Documentation

### Interactive Docs

Swagger UI is available at: `GET /api-docs`

### Authentication

All task endpoints require a JWT token in the `Authorization` header:

```
Authorization: Bearer <token>
```

### Endpoints

#### Auth

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/signup` | Register a new user | No |
| POST | `/login` | Login and get JWT token | No |

**Signup Request:**
```json
{
  "name": "John",
  "email": "john@example.com",
  "password": "password123",
  "password_confirmation": "password123"
}
```

**Login Request:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response:**
```json
{ "token": "eyJhbGciOi..." }
```

#### Tasks

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/tasks` | List tasks (with filters/pagination) | Yes |
| GET | `/tasks/:id` | Get a single task | Yes |
| POST | `/tasks` | Create a task | Yes |
| PUT | `/tasks/:id` | Update a task | Yes |
| DELETE | `/tasks/:id` | Delete a task | Yes |

**Create/Update Task Request:**
```json
{
  "task": {
    "title": "Buy groceries",
    "description": "Milk, eggs, bread",
    "status": "pending",
    "priority": "high",
    "due_date": "2026-04-01"
  }
}
```

**Query Parameters for `GET /tasks`:**

| Param | Description | Example |
|-------|-------------|---------|
| `status` | Filter by status | `?status=pending` |
| `priority` | Filter by priority | `?priority=high` |
| `search` | Search title (case-insensitive) | `?search=groceries` |
| `due_before` | Tasks due before date | `?due_before=2026-04-01` |
| `due_after` | Tasks due after date | `?due_after=2026-03-01` |
| `sort_by` | Sort field (`created_at`, `due_date`, `priority`) | `?sort_by=due_date` |
| `order` | Sort direction (`asc`, `desc`) | `?order=desc` |
| `page` | Page number | `?page=2` |
| `per_page` | Items per page | `?per_page=10` |

#### Health & Monitoring

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/up` | Basic health check (200 if app boots) | No |
| GET | `/health` | Detailed health check (DB + Redis status) | No |
| GET | `/sidekiq` | Sidekiq dashboard (Basic Auth) | Basic Auth |

**Health Check Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-03-23T12:00:00Z",
  "services": {
    "database": { "status": "ok" },
    "redis": { "status": "ok" }
  }
}
```

### Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| All requests (per IP) | 300 | 5 minutes |
| `POST /login` (per IP) | 5 | 20 seconds |
| `POST /signup` (per IP) | 3 | 1 minute |

Rate-limited responses return `429 Too Many Requests` with `RateLimit-*` headers.

---

## Deployment

### Heroku

```bash
# Login and create app
heroku login
heroku create your-app-name

# Add PostgreSQL and Redis
heroku addons:create heroku-postgresql:essential-0
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set SECRET_KEY_BASE=$(rails secret)
heroku config:set SIDEKIQ_USERNAME=admin
heroku config:set SIDEKIQ_PASSWORD=your_secure_password

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Railway

1. Connect your GitHub repository on Railway
2. Add **PostgreSQL** and **Redis** plugins
3. Set environment variables in the Railway dashboard:
   - `RAILS_MASTER_KEY`
   - `SECRET_KEY_BASE`
   - `SIDEKIQ_USERNAME` / `SIDEKIQ_PASSWORD`
4. Railway auto-detects the Dockerfile and deploys

### Render

1. Create a new **Web Service** on Render from your repo
2. Set environment to **Docker**
3. Add a **PostgreSQL** database and **Redis** instance
4. Set environment variables:
   - `DATABASE_URL` (from Render PostgreSQL)
   - `REDIS_URL` (from Render Redis)
   - `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`
5. Deploy

### Production Checklist

- [ ] Set strong `SECRET_KEY_BASE` and `RAILS_MASTER_KEY`
- [ ] Use strong, unique `POSTGRES_PASSWORD`
- [ ] Change `SIDEKIQ_USERNAME` and `SIDEKIQ_PASSWORD` from defaults
- [ ] Configure `CORS_ORIGINS` for your frontend domain
- [ ] Set up SMTP credentials for email delivery
- [ ] Enable SSL/TLS (`config.force_ssl = true`)
- [ ] Configure DNS rebinding protection (`config.hosts`)
- [ ] Set up log aggregation and monitoring
- [ ] Verify `/health` endpoint is reachable by load balancer

---

## Testing

```bash
# Run full test suite
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run specific tests
bundle exec rspec spec/controllers/
bundle exec rspec spec/models/
```

---

## Project Structure

```
app/
├── controllers/
│   ├── application_controller.rb   # JWT auth, error handling
│   ├── authentication_controller.rb # Signup/login
│   ├── health_controller.rb        # Health check endpoint
│   └── tasks_controller.rb         # CRUD + filtering/pagination
├── jobs/                           # Sidekiq background jobs
├── mailers/                        # Email delivery
├── models/
│   ├── task.rb                     # Task with scopes & validations
│   └── user.rb                     # User with has_secure_password
├── serializers/                    # ActiveModelSerializers
└── services/                       # Business logic
config/
├── initializers/
│   ├── cors.rb                     # CORS configuration
│   ├── rack_attack.rb              # Rate limiting
│   ├── sidekiq.rb                  # Redis connection
│   └── sidekiq_cron.rb             # Scheduled jobs
├── database.yml                    # PostgreSQL config
lib/
└── middleware/
    └── security_headers.rb         # Security headers middleware
├── puma.rb                         # Web server config
└── sidekiq.yml                     # Worker config
```

## License

MIT
