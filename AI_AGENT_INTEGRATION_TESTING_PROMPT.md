# AI Agent Integration Testing Prompt: Comprehensive Integration Test Implementation

## 🎯 OBJECTIVE
Implement comprehensive integration tests for a Python microservice codebase that verify real component interactions including database operations, message queues, external APIs, and cross-service workflows.

## 📋 SUCCESS CRITERIA
- ✅ 70-80% coverage of critical integration paths
- ✅ 100% coverage of critical user flows (auth, payments, data persistence)
- ✅ All integration tests passing (zero failures)
- ✅ Containerized test dependencies (reproducible environment)
- ✅ Proper test isolation (no test interdependencies)
- ✅ Transaction handling tested (commits, rollbacks)
- ✅ Error scenarios covered (network failures, timeouts)

---

## 🚀 STEP-BY-STEP EXECUTION GUIDE

### STEP 1: Initial Discovery & Analysis
**Execute these commands and analyze results:**

```bash
# 1.1 Check current test structure
find tests -type d -name "*" | head -20
ls -la tests/

# 1.2 Identify existing integration tests
find tests -name "*integration*" -o -name "*test_*" | grep -i integr

# 1.3 Analyze service dependencies
grep -r "import" app/ | grep -E "(redis|kafka|grpc|database|postgres)" | head -20

# 1.4 Check for docker-compose files
ls -la docker-compose*.yml 2>/dev/null || echo "No docker-compose files found"

# 1.5 Review pyproject.toml for test configuration
cat pyproject.toml | grep -A 20 "\[tool.pytest"
```

**Analysis Tasks:**
- [ ] Document current integration test coverage (if any)
- [ ] Identify all external dependencies (DB, Redis, Kafka, APIs)
- [ ] Map critical user flows that need integration testing
- [ ] Check existing test infrastructure
- [ ] Note service-to-service communication patterns

### STEP 2: Set Up Test Infrastructure

**2.1 Create `docker-compose.test.yml`:**
```yaml
version: '3.8'

services:
  test-postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_password
      POSTGRES_DB: test_db
    ports:
      - "5433:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user -d test_db"]
      interval: 5s
      timeout: 5s
      retries: 5

  test-redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
```

**2.2 Configure pytest markers in `pyproject.toml`:**
```toml
[tool.pytest.ini_options]
markers = [
    "unit: Unit tests (fast, mocked dependencies)",
    "integration: Integration tests (require real dependencies)",
    "e2e: End-to-end tests (full system)",
    "slow: Tests that take a long time to run",
]
```

**2.3 Validation:**
```bash
# Start test containers
docker-compose -f docker-compose.test.yml up -d

# Verify services are healthy
docker-compose -f docker-compose.test.yml ps

# Test database connection
PGPASSWORD=test_password psql -h localhost -p 5433 -U test_user -d test_db -c "SELECT 1"
```

### STEP 3: Create Integration Test Directory Structure

**3.1 Create directory structure:**
```bash
mkdir -p tests/integration/{database,api,messaging,cache,external,workflows}
touch tests/integration/__init__.py
touch tests/integration/conftest.py
touch tests/integration/database/__init__.py
touch tests/integration/api/__init__.py
touch tests/integration/messaging/__init__.py
touch tests/integration/cache/__init__.py
touch tests/integration/external/__init__.py
touch tests/integration/workflows/__init__.py
```

**3.2 Create integration `conftest.py`:**
```python
# tests/integration/conftest.py
import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("TESTING", "true")
os.environ.setdefault("DATABASE_URL", "postgresql://test_user:test_password@localhost:5433/test_db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6380/0")


@pytest.fixture(scope="session")
def test_engine():
    """Create test database engine."""
    engine = create_engine(os.environ["DATABASE_URL"])
    # Create tables
    from app.models.base import Base
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture(scope="function")
def db_session(test_engine):
    """Create isolated database session with transaction rollback."""
    connection = test_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def redis_client():
    """Create Redis client for testing."""
    import redis
    client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    yield client
    client.flushdb()
```

**Validation:**
```bash
poetry run pytest tests/integration --collect-only
```

### STEP 4: Implement Database Integration Tests

**4.1 Create database integration tests:**
```python
# tests/integration/database/test_user_repository.py
import pytest
from sqlalchemy.exc import IntegrityError
from app.models.user import User
from app.repositories.user_repository import UserRepository


@pytest.mark.integration
class TestIntegrationUserRepository:
    """Database integration tests for UserRepository."""

    def test_create_user_persists_correctly(self, db_session):
        """Test user creation with real database."""
        repo = UserRepository(db_session)

        user = repo.create(
            email="test@example.com",
            name="Test User",
            password_hash="hashed_password"
        )
        db_session.flush()

        # Query back from database
        saved_user = db_session.query(User).filter_by(
            email="test@example.com"
        ).first()

        assert saved_user is not None
        assert saved_user.name == "Test User"

    def test_unique_constraint_enforcement(self, db_session):
        """Test database unique constraints."""
        repo = UserRepository(db_session)

        repo.create(email="duplicate@example.com", name="First", password_hash="hash1")
        db_session.flush()

        with pytest.raises(IntegrityError):
            repo.create(email="duplicate@example.com", name="Second", password_hash="hash2")
            db_session.flush()

    def test_transaction_rollback_on_error(self, db_session):
        """Test transaction isolation."""
        repo = UserRepository(db_session)

        try:
            user = repo.create(email="rollback@example.com", name="Test", password_hash="hash")
            db_session.flush()
            raise Exception("Simulated error")
        except Exception:
            db_session.rollback()

        result = db_session.query(User).filter_by(email="rollback@example.com").first()
        assert result is None
```

**4.2 Run and verify:**
```bash
poetry run pytest tests/integration/database/ -v -m integration
```

### STEP 5: Implement API Integration Tests

**5.1 For gRPC services:**
```python
# tests/integration/api/test_grpc_user_service.py
import pytest
import grpc
from concurrent import futures
from app.grpc.user_service import UserServiceServicer
from app.grpc import user_pb2, user_pb2_grpc


@pytest.fixture(scope="module")
def grpc_server(test_engine):
    """Start gRPC server for testing."""
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    servicer = UserServiceServicer()
    user_pb2_grpc.add_UserServiceServicer_to_server(servicer, server)
    server.add_insecure_port('[::]:50052')
    server.start()
    yield server
    server.stop(grace=0)


@pytest.fixture
def grpc_channel(grpc_server):
    """Create gRPC channel."""
    channel = grpc.insecure_channel('localhost:50052')
    yield channel
    channel.close()


@pytest.mark.integration
class TestIntegrationGrpcUserService:

    def test_create_user_via_grpc(self, grpc_channel, db_session):
        """Test gRPC user creation."""
        stub = user_pb2_grpc.UserServiceStub(grpc_channel)

        request = user_pb2.CreateUserRequest(
            email="grpc@example.com",
            name="gRPC User"
        )

        response = stub.CreateUser(request)

        assert response.success is True
        assert response.user.email == "grpc@example.com"

    def test_grpc_validation_error(self, grpc_channel):
        """Test gRPC error handling."""
        stub = user_pb2_grpc.UserServiceStub(grpc_channel)

        request = user_pb2.CreateUserRequest(email="", name="")

        with pytest.raises(grpc.RpcError) as exc_info:
            stub.CreateUser(request)

        assert exc_info.value.code() == grpc.StatusCode.INVALID_ARGUMENT
```

**5.2 For REST APIs (if applicable):**
```python
# tests/integration/api/test_rest_endpoints.py
import pytest
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture
def client(db_session):
    """Create test client with database session."""
    with TestClient(app) as client:
        yield client


@pytest.mark.integration
class TestIntegrationRestAPI:

    def test_create_user_endpoint(self, client):
        """Test REST user creation."""
        response = client.post(
            "/api/v1/users",
            json={"email": "rest@example.com", "name": "REST User", "password": "Pass123!"}
        )

        assert response.status_code == 201
        assert response.json()["email"] == "rest@example.com"

    def test_validation_error_response(self, client):
        """Test REST validation errors."""
        response = client.post("/api/v1/users", json={"email": "invalid"})

        assert response.status_code == 422
```

### STEP 6: Implement Cache Integration Tests

```python
# tests/integration/cache/test_redis_cache.py
import pytest
import time
from app.services.cache_service import CacheService


@pytest.mark.integration
class TestIntegrationRedisCache:

    def test_cache_set_and_get(self, redis_client):
        """Test cache operations."""
        cache = CacheService(redis_client)

        cache.set("test_key", {"data": "value"}, ttl=60)
        result = cache.get("test_key")

        assert result["data"] == "value"

    def test_cache_expiration(self, redis_client):
        """Test TTL expiration."""
        cache = CacheService(redis_client)

        cache.set("expiring_key", {"temp": "data"}, ttl=1)
        assert cache.get("expiring_key") is not None

        time.sleep(2)
        assert cache.get("expiring_key") is None

    def test_cache_invalidation(self, redis_client):
        """Test cache invalidation."""
        cache = CacheService(redis_client)

        cache.set("user:123:profile", {"name": "Test"})
        cache.set("user:123:settings", {"theme": "dark"})

        cache.invalidate_pattern("user:123:*")

        assert cache.get("user:123:profile") is None
        assert cache.get("user:123:settings") is None
```

### STEP 7: Implement Workflow Integration Tests

```python
# tests/integration/workflows/test_user_registration_flow.py
import pytest
from app.services.user_service import UserService


@pytest.mark.integration
class TestIntegrationUserRegistrationFlow:
    """Test complete user registration workflow."""

    def test_complete_registration_flow(self, db_session, redis_client):
        """Test end-to-end registration."""
        user_service = UserService(db_session)

        # Step 1: Register
        user = user_service.register(
            email="newuser@example.com",
            password="SecurePass123!",
            name="New User"
        )
        assert user.id is not None
        assert user.is_verified is False

        # Step 2: Get verification token
        token = redis_client.get(f"verification_token:{user.id}")
        assert token is not None

        # Step 3: Verify email
        result = user_service.verify_email(user.id, token)
        assert result.is_verified is True

        # Step 4: Login
        auth = user_service.authenticate("newuser@example.com", "SecurePass123!")
        assert auth.access_token is not None
```


### STEP 8: Run Integration Tests

**8.1 Start test dependencies:**
```bash
docker-compose -f docker-compose.test.yml up -d
```

**8.2 Wait for services:**
```bash
# Simple wait script
sleep 10

# Or check health
docker-compose -f docker-compose.test.yml ps
```

**8.3 Run integration tests:**
```bash
# Run all integration tests
poetry run pytest -m integration -v

# Run with coverage
poetry run pytest -m integration --cov=app --cov-report=term-missing

# Run specific category
poetry run pytest tests/integration/database/ -v -m integration

# Run with detailed output
poetry run pytest -m integration -v --tb=long
```

**8.4 Cleanup:**
```bash
docker-compose -f docker-compose.test.yml down -v
```

---

## 🔧 TROUBLESHOOTING GUIDE

### Common Issues & Solutions:

**Database Connection Errors:**
```bash
# Verify database is running
docker-compose -f docker-compose.test.yml ps test-postgres

# Check connection
PGPASSWORD=test_password psql -h localhost -p 5433 -U test_user -d test_db -c "SELECT 1"

# Check logs
docker-compose -f docker-compose.test.yml logs test-postgres
```

**Redis Connection Errors:**
```bash
# Verify Redis is running
docker-compose -f docker-compose.test.yml ps test-redis

# Test connection
redis-cli -h localhost -p 6380 ping
```

**Test Isolation Issues:**
```python
# Ensure fixtures use transaction rollback
@pytest.fixture
def db_session(test_engine):
    connection = test_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()

    yield session

    session.close()
    transaction.rollback()  # Important: rollback after each test
    connection.close()
```

**Slow Test Execution:**
```python
# Use session-scoped fixtures for expensive setup
@pytest.fixture(scope="session")
def test_engine():
    # Create once, reuse for all tests
    ...

# Use module-scoped fixtures for related tests
@pytest.fixture(scope="module")
def grpc_server():
    # Start once per test module
    ...
```

---

## 📊 PROGRESS TRACKING

### Integration Test Milestones:
- [ ] **Infrastructure**: Docker Compose and pytest configuration complete
- [ ] **Database Tests**: CRUD, transactions, constraints tested
- [ ] **API Tests**: gRPC/REST endpoints integration tested
- [ ] **Cache Tests**: Redis operations and expiration tested
- [ ] **Workflow Tests**: Critical user flows tested end-to-end

### Coverage Checkpoints:
- [ ] **50%**: Core database operations covered
- [ ] **60%**: API endpoints covered
- [ ] **70%**: Cache and messaging covered
- [ ] **80%**: Critical workflows covered

### Quality Gates:
- [ ] All integration tests passing (0 failures)
- [ ] Proper test isolation (no interdependencies)
- [ ] Containerized dependencies (reproducible)
- [ ] Documentation complete

---

## 🎯 FINAL VALIDATION

**Run complete integration test suite:**
```bash
# Start dependencies
docker-compose -f docker-compose.test.yml up -d

# Wait for readiness
sleep 15

# Run all integration tests with coverage
poetry run pytest -m integration --cov=app --cov-report=term-missing -v

# Check results
echo "Expected: 70-80% coverage of critical paths, 0 failures"
```

**Success criteria met when:**
✅ 70-80% coverage of critical integration paths
✅ 100% coverage of critical user flows
✅ All integration tests passing (0 failures)
✅ Proper test isolation verified
✅ Containerized environment reproducible

---

## 🤖 COPY-PASTE PROMPT FOR AI AGENTS

**Use this exact prompt to start the integration testing process:**

```
I need you to implement comprehensive integration tests for this Python microservice codebase.

OBJECTIVE: Implement integration tests that verify real component interactions including database operations, message queues, and cross-service workflows.

KEY DIFFERENCES FROM UNIT TESTS:
- Use REAL dependencies (containerized via Docker Compose), not mocks
- Test component INTERACTIONS, not isolated functions
- Focus on CRITICAL PATHS (auth, payments, data persistence)
- Target 70-80% coverage of integration paths

APPROACH:
1. First, analyze the current codebase and identify integration points
2. Set up Docker Compose for test dependencies (Postgres, Redis, Kafka)
3. Create integration test directory structure under tests/integration/
4. Configure pytest markers to separate unit and integration tests
5. Implement tests in order: database → API → cache → workflows
6. Ensure proper test isolation with transaction rollback
7. Follow the step-by-step guide in AI_AGENT_INTEGRATION_TESTING_PROMPT.md

START with: Setting up docker-compose.test.yml and tests/integration/conftest.py

VALIDATION: Each step should add more integration path coverage while maintaining 100% pass rate.

PRIORITY:
1. Database CRUD and transactions
2. API endpoint integrations (gRPC/REST)
3. Cache operations
4. Critical user flow workflows

Provide integration test coverage reports after each major milestone.
```

---

## 📝 QUICK REFERENCE

### Running Tests
```bash
# Unit tests only (fast)
poetry run pytest -m "not integration"

# Integration tests only
poetry run pytest -m integration

# All tests
poetry run pytest

# Specific integration category
poetry run pytest tests/integration/database/ -m integration
```

### Test Markers
```python
@pytest.mark.unit        # Fast, mocked tests
@pytest.mark.integration # Require real dependencies
@pytest.mark.e2e         # Full system tests
@pytest.mark.slow        # Long-running tests
```

### Fixture Scopes
```python
scope="function"  # Default: fresh for each test
scope="class"     # Shared within test class
scope="module"    # Shared within test file
scope="session"   # Shared across all tests
```

