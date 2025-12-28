# 📄 AI-Agent Driven Testing Workflow for Microservices

## 🎯 Purpose
This repository provides a standardized approach for writing test cases across all microservices using **AI-assisted agents** (e.g., Augment Code, Cursor, Roo Code, GitHub Copilot).  
The goal is to ensure **consistent test methodology**, **comprehensive coverage**, and **high-quality test design** across the team.

---

## 📁 Repository Structure

```
.
├── README.md                              # This file
├── TESTING_METHODOLOGY.md                 # Unit testing methodology
├── AI_AGENT_TESTING_PROMPT.md             # AI agent prompt for unit tests
├── INTEGRATION_TESTING_METHODOLOGY.md     # Integration testing methodology
└── AI_AGENT_INTEGRATION_TESTING_PROMPT.md # AI agent prompt for integration tests
```

---

## 🧪 Testing Types Overview

| Test Type | Purpose | Dependencies | Coverage Target |
|-----------|---------|--------------|-----------------|
| **Unit Tests** | Test isolated functions/classes | All mocked | 90-95% |
| **Integration Tests** | Test component interactions | Real (containerized) | 70-80% critical paths |

---

## 📘 Unit Testing

### How to Use

1. **Copy Methodology to Your Service**
   ```bash
   cp ../shared/TESTING_METHODOLOGY.md ./docs/TESTING_METHODOLOGY.md
   ```

2. **Use AI Agents for Test Generation**
   - Open your service in **Augment Code, Cursor, Roo Code, or other AI-assisted IDEs**
   - Provide the agent with `docs/TESTING_METHODOLOGY.md` for context

3. **Provide the Testing Prompt**
   - Give the agent the prompt from `AI_AGENT_TESTING_PROMPT.md`

4. **Run Tests with Coverage**
   ```bash
   poetry run pytest --cov=app --cov-report=term-missing
   ```

### Key Principles
- ✅ Mock all external dependencies (database, APIs, gRPC)
- ✅ Target 90-95% overall coverage
- ✅ 90%+ coverage per file
- ✅ Test happy paths, error handling, edge cases

---

## 🔗 Integration Testing

### How to Use

1. **Copy Methodology to Your Service**
   ```bash
   cp ../shared/INTEGRATION_TESTING_METHODOLOGY.md ./docs/INTEGRATION_TESTING_METHODOLOGY.md
   ```

2. **Set Up Test Infrastructure**
   - Copy `docker-compose.test.yml` template from methodology
   - Configure containerized dependencies (Postgres, Redis, Kafka)

3. **Use AI Agents for Test Generation**
   - Provide the agent with `docs/INTEGRATION_TESTING_METHODOLOGY.md`
   - Give the agent the prompt from `AI_AGENT_INTEGRATION_TESTING_PROMPT.md`

4. **Run Integration Tests**
   ```bash
   # Start test containers
   docker-compose -f docker-compose.test.yml up -d
   
   # Run integration tests
   poetry run pytest -m integration --cov=app --cov-report=term-missing
   
   # Cleanup
   docker-compose -f docker-compose.test.yml down -v
   ```

### Key Principles
- ✅ Use real (containerized) dependencies, not mocks
- ✅ Test component interactions and data flow
- ✅ Focus on critical user paths (auth, payments, data persistence)
- ✅ Ensure proper test isolation with transaction rollback

---

## 🔄 Standard Workflow for Each Developer

### For Unit Tests:
1. Copy `TESTING_METHODOLOGY.md` to your microservice
2. Open the microservice in your AI-assisted IDE
3. Load the methodology file as context
4. Paste `AI_AGENT_TESTING_PROMPT.md` into the AI agent
5. Review and run generated tests
6. Verify 90%+ coverage target

### For Integration Tests:
1. Copy `INTEGRATION_TESTING_METHODOLOGY.md` to your microservice
2. Set up `docker-compose.test.yml` with test dependencies
3. Create `tests/integration/` directory structure
4. Paste `AI_AGENT_INTEGRATION_TESTING_PROMPT.md` into the AI agent
5. Review and run generated tests
6. Verify critical paths are covered

---

## 📊 Coverage Targets Summary

| Metric | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| **Overall Coverage** | 90-95% | 70-80% critical paths |
| **Per-File Coverage** | 90%+ | N/A |
| **Critical User Flows** | 95%+ | 100% |
| **Error Handling** | 90%+ | 80%+ |
| **Test Pass Rate** | 100% | 100% |

---

## 🛠️ Quick Commands

```bash
# Run unit tests only
poetry run pytest -m "not integration"

# Run integration tests only
poetry run pytest -m integration

# Run all tests
poetry run pytest

# Generate HTML coverage report
poetry run pytest --cov=app --cov-report=html
open htmlcov/index.html
```

---

## 📚 Documentation Files

- **[TESTING_METHODOLOGY.md](./TESTING_METHODOLOGY.md)** - Complete unit testing methodology
- **[AI_AGENT_TESTING_PROMPT.md](./AI_AGENT_TESTING_PROMPT.md)** - Copy-paste prompt for AI agents (unit tests)
- **[INTEGRATION_TESTING_METHODOLOGY.md](./INTEGRATION_TESTING_METHODOLOGY.md)** - Complete integration testing methodology
- **[AI_AGENT_INTEGRATION_TESTING_PROMPT.md](./AI_AGENT_INTEGRATION_TESTING_PROMPT.md)** - Copy-paste prompt for AI agents (integration tests)

