#!/bin/bash

# Generic Test Runner Script
# Works with any Python project using poetry + pytest + docker-compose.test.yml

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config - modify these if needed
DOCKER_COMPOSE_FILE="docker-compose.test.yml"
TEST_DIR="tests"
INTEGRATION_DIR="tests/integration"
COV_SOURCE="app"

run_unit_tests() {
    poetry run pytest "$TEST_DIR" -v -m "not integration" --tb=short "$@"
}

run_integration_tests() {
    poetry run pytest "$INTEGRATION_DIR" -v -m integration --tb=short "$@"
}

run_all_tests() {
    poetry run pytest "$TEST_DIR" -v --tb=short "$@"
}

start_docker() {
    echo -e "${YELLOW}Starting Docker containers...${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
    sleep 3
    if ! docker-compose -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
        echo -e "${RED}Error: Docker containers failed to start${NC}"
        return 1
    fi
    echo -e "${GREEN}Docker containers ready${NC}"
}

stop_docker() {
    echo -e "${YELLOW}Stopping Docker containers...${NC}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" down -v
    echo -e "${GREEN}Done${NC}"
}

check_docker() {
    docker-compose -f "$DOCKER_COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"
}

show_menu() {
    echo ""
    echo -e "${BLUE}Test Runner${NC}"
    echo ""
    echo "  1) Unit tests"
    echo "  2) Integration tests (Docker)"
    echo "  3) All tests (Docker)"
    echo "  4) Unit tests + coverage"
    echo "  5) Docker status"
    echo "  6) Stop Docker"
    echo "  q) Quit"
    echo ""
}

while true; do
    show_menu
    read -p "Choice: " choice
    echo ""

    case $choice in
        1)
            run_unit_tests
            ;;
        2)
            if ! check_docker; then
                read -p "Start Docker? [y/N]: " yn
                [[ $yn =~ ^[Yy]$ ]] && start_docker || continue
            fi
            run_integration_tests
            read -p "Stop Docker? [y/N]: " yn
            [[ $yn =~ ^[Yy]$ ]] && stop_docker
            ;;
        3)
            if ! check_docker; then
                read -p "Start Docker? [y/N]: " yn
                [[ $yn =~ ^[Yy]$ ]] && start_docker || continue
            fi
            run_all_tests
            read -p "Stop Docker? [y/N]: " yn
            [[ $yn =~ ^[Yy]$ ]] && stop_docker
            ;;
        4)
            poetry run pytest "$TEST_DIR" -m "not integration" --cov="$COV_SOURCE" --cov-report=html --cov-report=term-missing
            echo -e "${GREEN}Coverage: htmlcov/index.html${NC}"
            ;;
        5)
            docker-compose -f "$DOCKER_COMPOSE_FILE" ps
            ;;
        6)
            stop_docker
            ;;
        q|Q)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
done

