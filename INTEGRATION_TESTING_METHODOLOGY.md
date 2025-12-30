# Comprehensive Integration Testing Methodology for AI Agents

## Overview
This document outlines the systematic approach for implementing integration tests in Python microservices. Integration tests verify that multiple components work together correctly, including service-to-service communication, database operations, message queues, and external API interactions.

## Unit Tests vs Integration Tests

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| **Scope** | Single function/class in isolation | Multiple components working together |
| **Dependencies** | All mocked | Real or containerized dependencies |
| **Speed** | Fast (ms) | Slower (seconds) |
| **Purpose** | Verify logic correctness | Verify component interactions |
| **Database** | Mocked | Real test database (containerized) |
| **External APIs** | Mocked | Real or sandbox environments |
| **Coverage Target** | 90-95% | Critical paths (70-80%) |

## Phase 0: Initial Discovery & Analysis

### 0.1 Integration Points Identification
1. **Map service boundaries** - Identify all microservice interactions
2. **Database interactions** - List all database operations (CRUD, transactions)
3. **Message queues** - Kafka, RabbitMQ, Redis pub/sub integrations
4. **External APIs** - Third-party services, payment gateways, auth providers
5. **gRPC/REST endpoints** - Inter-service communication patterns
6. **Cache layers** - Redis, Memcached interactions
7. **File storage** - S3, GCS, local filesystem operations

### 0.2 Integration Test Strategy Planning
1. **Define critical paths** - User journeys that span multiple services
2. **Prioritize by risk** - Payment flows, auth flows, data consistency
3. **Plan test data strategy** - Fixtures, factories, seed data
4. **Choose containerization approach** - Docker Compose, Testcontainers
5. **Design cleanup strategy** - Database reset, queue drain, cache flush

## Phase 1: Test Infrastructure Setup

### 1.1 Docker Compose Configuration for Test Dependencies
```yaml
# docker-compose.test.yml
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

  test-kafka:
    image: confluentinc/cp-kafka:7.5.0
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9093
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      CLUSTER_ID: 'test-cluster-id'
    ports:
      - "9093:9092"
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
      interval: 10s
      timeout: 10s
      retries: 5
```

### 1.2 Pytest Configuration for Integration Tests
```toml
# pyproject.toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
markers = [
    "unit: Unit tests (fast, mocked dependencies)",
    "integration: Integration tests (require real dependencies)",
    "e2e: End-to-end tests (full system)",
    "slow: Tests that take a long time to run",
]
addopts = "-v --tb=short"
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "function"

# Run only unit tests by default
# Use: pytest -m integration for integration tests
```

### 1.3 Environment Configuration
```python
# tests/integration/conftest.py
import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Integration test environment variables
os.environ.setdefault("TESTING", "true")
os.environ.setdefault("DATABASE_URL", "postgresql://test_user:test_password@localhost:5433/test_db")
os.environ.setdefault("REDIS_URL", "redis://localhost:6380/0")
os.environ.setdefault("KAFKA_BOOTSTRAP_SERVERS", "localhost:9093")


@pytest.fixture(scope="session")
def test_engine():
    """Create test database engine."""
    engine = create_engine(os.environ["DATABASE_URL"])
    yield engine
    engine.dispose()


@pytest.fixture(scope="function")
def db_session(test_engine):
    """Create isolated database session for each test."""
    connection = test_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()

    yield session

    session.close()
    transaction.rollback()
    connection.close()
```

## Phase 2: Test Directory Structure

### 2.1 Integration Test Organization
```
tests/
├── unit/                          # Unit tests (existing structure)
│   ├── services/
│   ├── models/
│   └── utils/
├── integration/                   # Integration tests
│   ├── __init__.py
│   ├── conftest.py               # Integration-specific fixtures
│   ├── database/                  # Database integration tests
│   │   ├── __init__.py
│   │   ├── test_transactions.py
│   │   └── test_migrations.py
│   ├── api/                       # API endpoint integration tests
│   │   ├── __init__.py
│   │   ├── test_grpc_endpoints.py
│   │   └── test_rest_endpoints.py
│   ├── messaging/                 # Message queue integration tests
│   │   ├── __init__.py
│   │   ├── test_kafka_producers.py
│   │   └── test_kafka_consumers.py
│   ├── external/                  # External service integration tests
│   │   ├── __init__.py
│   │   ├── test_payment_gateway.py
│   │   └── test_auth_provider.py
│   ├── cache/                     # Cache integration tests
│   │   ├── __init__.py
│   │   └── test_redis_cache.py
│   └── workflows/                 # Cross-service workflow tests
│       ├── __init__.py
│       ├── test_user_registration_flow.py
│       └── test_order_processing_flow.py
└── e2e/                           # End-to-end tests
    ├── __init__.py
    └── test_complete_user_journey.py
```

### 2.2 Naming Conventions
```python
# File naming: test_{component}_{integration_type}.py
# Class naming: TestIntegration{ComponentName}
# Method naming: test_{scenario}_{expected_outcome}

# Examples:
# tests/integration/database/test_user_repository.py
class TestIntegrationUserRepository:
    def test_create_user_persists_to_database(self):
        """Test that user creation actually writes to the database."""

    def test_create_user_with_duplicate_email_raises_integrity_error(self):
        """Test database constraint enforcement."""

    def test_user_transaction_rollback_on_error(self):
        """Test transaction isolation and rollback behavior."""
```

## Phase 3: Integration Test Patterns

### 3.1 Database Integration Testing
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

        # Verify persistence
        db_session.flush()

        # Query back from database
        saved_user = db_session.query(User).filter_by(email="test@example.com").first()

        assert saved_user is not None
        assert saved_user.name == "Test User"
        assert saved_user.id == user.id

    def test_create_user_duplicate_email_raises_error(self, db_session):
        """Test database unique constraint enforcement."""
        repo = UserRepository(db_session)

        repo.create(email="duplicate@example.com", name="First User", password_hash="hash1")
        db_session.flush()

        with pytest.raises(IntegrityError):
            repo.create(email="duplicate@example.com", name="Second User", password_hash="hash2")
            db_session.flush()

    def test_transaction_rollback_on_error(self, db_session):
        """Test that failed transactions don't persist partial data."""
        repo = UserRepository(db_session)

        try:
            user = repo.create(email="rollback@example.com", name="Test", password_hash="hash")
            db_session.flush()
            raise Exception("Simulated error")
        except Exception:
            db_session.rollback()

        # Verify user was not persisted
        result = db_session.query(User).filter_by(email="rollback@example.com").first()
        assert result is None
```

### 3.2 gRPC Service Integration Testing
```python
# tests/integration/api/test_grpc_user_service.py
import pytest
import grpc
from concurrent import futures
from app.grpc.user_service import UserServiceServicer
from app.grpc import user_pb2, user_pb2_grpc


@pytest.fixture(scope="module")
def grpc_server(test_engine):
    """Start a real gRPC server for integration testing."""
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    servicer = UserServiceServicer()
    user_pb2_grpc.add_UserServiceServicer_to_server(servicer, server)
    server.add_insecure_port('[::]:50052')
    server.start()
    yield server
    server.stop(grace=0)


@pytest.fixture
def grpc_channel(grpc_server):
    """Create a gRPC channel to the test server."""
    channel = grpc.insecure_channel('localhost:50052')
    yield channel
    channel.close()


@pytest.mark.integration
class TestIntegrationUserGrpcService:
    """gRPC integration tests for User service."""

    def test_create_user_via_grpc(self, grpc_channel, db_session):
        """Test complete gRPC user creation flow."""
        stub = user_pb2_grpc.UserServiceStub(grpc_channel)

        request = user_pb2.CreateUserRequest(
            email="grpc_test@example.com",
            name="gRPC Test User"
        )

        response = stub.CreateUser(request)

        assert response.success is True
        assert response.user.email == "grpc_test@example.com"

        # Verify in database
        user = db_session.query(User).filter_by(email="grpc_test@example.com").first()
        assert user is not None

    def test_grpc_error_handling(self, grpc_channel):
        """Test gRPC error responses."""
        stub = user_pb2_grpc.UserServiceStub(grpc_channel)

        # Request with invalid data
        request = user_pb2.CreateUserRequest(email="", name="")

        with pytest.raises(grpc.RpcError) as exc_info:
            stub.CreateUser(request)

        assert exc_info.value.code() == grpc.StatusCode.INVALID_ARGUMENT
```


### 3.3 Kafka/Message Queue Integration Testing
```python
# tests/integration/messaging/test_kafka_integration.py
import pytest
import json
import time
from kafka import KafkaProducer, KafkaConsumer
from app.services.event_publisher import EventPublisher
from app.services.event_consumer import EventConsumer


@pytest.fixture(scope="module")
def kafka_producer():
    """Create real Kafka producer for testing."""
    producer = KafkaProducer(
        bootstrap_servers=['localhost:9093'],
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        key_serializer=lambda k: k.encode('utf-8') if k else None
    )
    yield producer
    producer.close()


@pytest.fixture(scope="module")
def kafka_consumer():
    """Create real Kafka consumer for testing."""
    consumer = KafkaConsumer(
        'test-topic',
        bootstrap_servers=['localhost:9093'],
        value_deserializer=lambda v: json.loads(v.decode('utf-8')),
        auto_offset_reset='earliest',
        consumer_timeout_ms=5000,
        group_id='test-group'
    )
    yield consumer
    consumer.close()


@pytest.mark.integration
class TestIntegrationKafkaMessaging:
    """Kafka messaging integration tests."""

    def test_publish_event_to_kafka(self, kafka_producer, kafka_consumer):
        """Test publishing events to Kafka."""
        event_publisher = EventPublisher(kafka_producer)

        event_data = {
            "event_type": "user_created",
            "user_id": "123",
            "timestamp": "2024-01-15T10:00:00Z"
        }

        # Publish event
        event_publisher.publish("test-topic", event_data, key="user-123")

        # Wait for message
        time.sleep(1)

        # Consume and verify
        messages = list(kafka_consumer)
        assert len(messages) > 0

        last_message = messages[-1]
        assert last_message.value["event_type"] == "user_created"
        assert last_message.value["user_id"] == "123"

    def test_consumer_processes_message(self, kafka_producer, db_session):
        """Test that consumer correctly processes messages."""
        consumer = EventConsumer(db_session)

        # Publish test event
        kafka_producer.send(
            'user-events',
            value={"event_type": "user_updated", "user_id": "456", "name": "Updated Name"},
            key="user-456"
        )
        kafka_producer.flush()

        # Process message
        consumer.process_next_message(timeout_ms=5000)

        # Verify side effects in database
        # (depends on your consumer logic)
```

### 3.4 Redis Cache Integration Testing
```python
# tests/integration/cache/test_redis_cache.py
import pytest
import redis
from app.services.cache_service import CacheService


@pytest.fixture
def redis_client():
    """Create real Redis client for testing."""
    client = redis.Redis(host='localhost', port=6380, db=0, decode_responses=True)
    yield client
    client.flushdb()  # Clean up after tests


@pytest.mark.integration
class TestIntegrationRedisCache:
    """Redis cache integration tests."""

    def test_cache_set_and_get(self, redis_client):
        """Test basic cache operations."""
        cache_service = CacheService(redis_client)

        cache_service.set("test_key", {"data": "value"}, ttl=60)

        result = cache_service.get("test_key")

        assert result is not None
        assert result["data"] == "value"

    def test_cache_expiration(self, redis_client):
        """Test cache TTL expiration."""
        cache_service = CacheService(redis_client)

        cache_service.set("expiring_key", {"temp": "data"}, ttl=1)

        # Should exist immediately
        assert cache_service.get("expiring_key") is not None

        # Wait for expiration
        import time
        time.sleep(2)

        # Should be expired
        assert cache_service.get("expiring_key") is None

    def test_cache_invalidation(self, redis_client):
        """Test cache invalidation patterns."""
        cache_service = CacheService(redis_client)

        # Set related keys
        cache_service.set("user:123:profile", {"name": "Test"})
        cache_service.set("user:123:settings", {"theme": "dark"})

        # Invalidate all user keys
        cache_service.invalidate_pattern("user:123:*")

        assert cache_service.get("user:123:profile") is None
        assert cache_service.get("user:123:settings") is None
```

### 3.5 External API Integration Testing
```python
# tests/integration/external/test_payment_gateway.py
import pytest
import responses
from app.services.payment_service import PaymentService


@pytest.fixture
def payment_service():
    """Create payment service with sandbox configuration."""
    return PaymentService(
        api_key="test_sandbox_key",
        environment="sandbox"
    )


@pytest.mark.integration
class TestIntegrationPaymentGateway:
    """Payment gateway integration tests (using sandbox)."""

    @pytest.mark.skipif(
        not os.environ.get("PAYMENT_SANDBOX_KEY"),
        reason="Payment sandbox credentials not configured"
    )
    def test_create_payment_intent(self, payment_service):
        """Test creating a payment intent with sandbox."""
        result = payment_service.create_payment_intent(
            amount=1000,  # $10.00
            currency="usd",
            customer_id="test_customer"
        )

        assert result.id is not None
        assert result.status == "requires_payment_method"
        assert result.amount == 1000

    @responses.activate
    def test_payment_failure_handling(self, payment_service):
        """Test payment failure scenarios with mocked responses."""
        # Mock external API for failure scenarios
        responses.add(
            responses.POST,
            "https://api.payment-gateway.com/v1/payment_intents",
            json={"error": {"code": "card_declined", "message": "Card was declined"}},
            status=402
        )

        with pytest.raises(PaymentDeclinedError):
            payment_service.create_payment_intent(
                amount=1000,
                currency="usd",
                customer_id="test_customer"
            )
```

## Phase 4: Workflow/End-to-End Integration Tests

### 4.1 Cross-Service Workflow Testing
```python
# tests/integration/workflows/test_user_registration_flow.py
import pytest
from app.services.user_service import UserService
from app.services.email_service import EmailService
from app.services.notification_service import NotificationService


@pytest.mark.integration
class TestIntegrationUserRegistrationFlow:
    """Test complete user registration workflow."""

    def test_complete_registration_flow(
        self, db_session, redis_client, kafka_producer
    ):
        """Test end-to-end user registration."""
        user_service = UserService(db_session)

        # Step 1: Register user
        user = user_service.register(
            email="newuser@example.com",
            password="SecurePass123!",
            name="New User"
        )

        assert user.id is not None
        assert user.is_verified is False

        # Step 2: Verify email token was created
        token = redis_client.get(f"verification_token:{user.id}")
        assert token is not None

        # Step 3: Simulate email verification
        result = user_service.verify_email(user.id, token)
        assert result.is_verified is True

        # Step 4: Verify welcome event was published
        # (check Kafka or event store)

        # Step 5: Verify user can now login
        auth_result = user_service.authenticate(
            email="newuser@example.com",
            password="SecurePass123!"
        )
        assert auth_result.access_token is not None
```

### 4.2 Data Consistency Testing
```python
# tests/integration/workflows/test_data_consistency.py
import pytest
from concurrent.futures import ThreadPoolExecutor
from app.services.inventory_service import InventoryService


@pytest.mark.integration
class TestIntegrationDataConsistency:
    """Test data consistency under concurrent operations."""

    def test_concurrent_inventory_updates(self, db_session):
        """Test that concurrent updates maintain consistency."""
        inventory_service = InventoryService(db_session)

        # Create item with 100 units
        item = inventory_service.create_item("SKU-001", quantity=100)
        db_session.commit()

        # Simulate concurrent purchases
        def purchase(amount):
            try:
                return inventory_service.reduce_quantity("SKU-001", amount)
            except Exception:
                return None

        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(purchase, 10) for _ in range(15)]
            results = [f.result() for f in futures]

        # Should have exactly 10 successful purchases (100 units / 10 per purchase)
        successful = [r for r in results if r is not None]
        assert len(successful) == 10

        # Final quantity should be 0
        db_session.refresh(item)
        assert item.quantity == 0
```


## Phase 5: Test Data Management

### 5.1 Test Data Factory Pattern
```python
# tests/integration/factories.py
import factory
from factory.alchemy import SQLAlchemyModelFactory
from app.models.user import User
from app.models.order import Order


class UserFactory(SQLAlchemyModelFactory):
    class Meta:
        model = User
        sqlalchemy_session_persistence = "commit"

    id = factory.Faker('uuid4')
    email = factory.Faker('email')
    name = factory.Faker('name')
    password_hash = factory.LazyFunction(lambda: hash_password("TestPass123!"))
    is_active = True
    is_verified = False


class OrderFactory(SQLAlchemyModelFactory):
    class Meta:
        model = Order
        sqlalchemy_session_persistence = "commit"

    id = factory.Faker('uuid4')
    user = factory.SubFactory(UserFactory)
    status = "pending"
    total_amount = factory.Faker('pydecimal', left_digits=4, right_digits=2, positive=True)


# Usage in tests
@pytest.fixture
def user_factory(db_session):
    UserFactory._meta.sqlalchemy_session = db_session
    return UserFactory


def test_with_factory(user_factory):
    user = user_factory.create(email="custom@example.com")
    assert user.id is not None
```

### 5.2 Database Seeding
```python
# tests/integration/seed_data.py
def seed_test_database(session):
    """Seed database with required reference data."""
    # Create roles
    roles = [
        Role(id="admin", name="Administrator"),
        Role(id="user", name="Standard User"),
    ]
    session.add_all(roles)

    # Create test users
    admin_user = User(
        id="admin-user-id",
        email="admin@test.com",
        role_id="admin"
    )
    session.add(admin_user)

    session.commit()


@pytest.fixture(scope="session")
def seeded_db(test_engine):
    """Fixture that seeds database once per session."""
    Base.metadata.create_all(test_engine)

    Session = sessionmaker(bind=test_engine)
    session = Session()
    seed_test_database(session)
    session.close()

    yield test_engine

    Base.metadata.drop_all(test_engine)
```

### 5.3 Test Isolation and Cleanup
```python
# tests/integration/conftest.py
@pytest.fixture(autouse=True)
def clean_redis(redis_client):
    """Clean Redis before and after each test."""
    redis_client.flushdb()
    yield
    redis_client.flushdb()


@pytest.fixture(autouse=True)
def clean_kafka(kafka_admin_client):
    """Clean Kafka topics before each test."""
    # Delete and recreate test topics
    topics = ['test-topic', 'user-events', 'order-events']
    try:
        kafka_admin_client.delete_topics(topics)
    except Exception:
        pass  # Topics may not exist

    # Recreate topics
    from kafka.admin import NewTopic
    new_topics = [NewTopic(name=t, num_partitions=1, replication_factor=1) for t in topics]
    kafka_admin_client.create_topics(new_topics)

    yield


@pytest.fixture
def db_session(test_engine):
    """Isolated database session with automatic rollback."""
    connection = test_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()

    yield session

    session.close()
    transaction.rollback()  # Undo all changes
    connection.close()
```

## Phase 6: Running Integration Tests

### 6.1 Running Integration Tests Locally
```bash
# Start test dependencies
docker-compose -f docker-compose.test.yml up -d

# Wait for services to be ready
sleep 10  # Or use a health check script

# Run integration tests
poetry run pytest -m integration -v

# Run with coverage
poetry run pytest -m integration --cov=app --cov-report=term-missing

# Run specific integration test file
poetry run pytest tests/integration/database/test_user_repository.py -v

# Cleanup
docker-compose -f docker-compose.test.yml down -v
```

## Phase 7: Best Practices & Guidelines

### 7.1 Integration Test Principles
1. **Test real interactions** - Use actual dependencies, not mocks
2. **Isolate test data** - Each test should have its own data context
3. **Clean up after tests** - Don't leave residual data
4. **Use transactions for rollback** - Wrap tests in transactions when possible
5. **Test failure scenarios** - Network failures, timeouts, constraint violations
6. **Test edge cases** - Empty results, large datasets, concurrent access

### 7.2 Performance Considerations
```python
# Use session-scoped fixtures for expensive setup
@pytest.fixture(scope="session")
def test_engine():
    """Create engine once per test session."""
    engine = create_engine(DATABASE_URL)
    Base.metadata.create_all(engine)
    yield engine
    engine.dispose()

# Use module-scoped fixtures for related tests
@pytest.fixture(scope="module")
def grpc_server():
    """Start gRPC server once per test module."""
    server = start_test_server()
    yield server
    server.stop()

# Use function-scoped fixtures for test isolation
@pytest.fixture(scope="function")
def db_session(test_engine):
    """Fresh session for each test."""
    ...
```

### 7.3 Debugging Integration Tests
```python
# Add detailed logging for debugging
import logging

@pytest.fixture(autouse=True)
def configure_logging():
    logging.basicConfig(level=logging.DEBUG)
    logging.getLogger('sqlalchemy.engine').setLevel(logging.INFO)


# Use pytest's built-in debugging
# pytest --pdb  # Drop into debugger on failure
# pytest -x     # Stop on first failure
# pytest -v     # Verbose output
```

## Success Metrics

### Coverage Targets (Integration Tests)
- **Critical user flows**: 100% coverage
- **Database operations**: 80%+ coverage
- **Message queue operations**: 75%+ coverage
- **External API integrations**: 70%+ coverage (with sandboxes/mocks)
- **Error handling paths**: 80%+ coverage

### Quality Gates
- ✅ All integration tests passing (0 failures)
- ✅ Critical paths covered (authentication, payments, data persistence)
- ✅ Proper test isolation (no test interdependencies)
- ✅ Reasonable execution time (< 5 minutes for full suite)
- ✅ Containerized dependencies (reproducible environment)

## Key Differences from Unit Testing

| Unit Tests | Integration Tests |
|-----------|-------------------|
| Mock all dependencies | Use real/containerized dependencies |
| Test single function | Test component interactions |
| Fast execution (ms) | Slower execution (seconds) |
| Run on every commit | Run on PR/scheduled |
| 90-95% coverage goal | 70-80% critical path coverage |
| Isolated from infrastructure | Requires infrastructure setup |

## Implementation Checklist for AI Agents

### ✅ Phase 1: Infrastructure Setup
- [ ] Create `docker-compose.test.yml` with test dependencies
- [ ] Configure pytest markers for test categorization
- [ ] Set up environment variables for test configuration
- [ ] Create integration test `conftest.py` with fixtures

### ✅ Phase 2: Test Organization
- [ ] Create `tests/integration/` directory structure
- [ ] Organize tests by component (database, api, messaging, etc.)
- [ ] Add `__init__.py` files to all test directories
- [ ] Implement naming conventions

### ✅ Phase 3: Core Integration Tests
- [ ] Database CRUD operations
- [ ] Transaction handling and rollback
- [ ] API endpoint integration (gRPC/REST)
- [ ] Message queue publish/consume

### ✅ Phase 4: Advanced Testing
- [ ] External service integrations (with sandboxes)
- [ ] Cache operations
- [ ] Cross-service workflows
- [ ] Data consistency under concurrency

### ✅ Phase 5: Test Data Management
- [ ] Implement factory patterns
- [ ] Create seed data scripts
- [ ] Configure test isolation and cleanup

## Expected Outcomes
- **70-80% coverage** of critical integration paths
- **Zero failing tests** in test suite
- **Reproducible test environment** via Docker
- **Fast feedback loop** for integration issues
- **Confidence in deployments** through comprehensive testing
