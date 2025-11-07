#!/bin/bash
# Quick start script for running load tests locally

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Zava Shop ChatKit Load Test ===${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}Created .env file. Please review and update if needed.${NC}"
    echo ""
fi

# Check if dependencies are installed
echo -e "${BLUE}Checking dependencies...${NC}"
if ! python3 -c "import locust" 2>/dev/null; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    pip install -r requirements.txt
    echo -e "${GREEN}Dependencies installed!${NC}"
    echo ""
else
    echo -e "${GREEN}Dependencies already installed.${NC}"
    echo ""
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default values
USERS=${VIRTUAL_USERS:-50}
DURATION=${DURATION:-300}
HOST=${HOST:-https://zavalife.com}

echo -e "${BLUE}Load Test Configuration:${NC}"
echo "  Host: $HOST"
echo "  Users: $USERS"
echo "  Duration: ${DURATION}s"
echo ""

# Parse command line arguments
MODE=${1:-ui}

case $MODE in
    ui)
        echo -e "${GREEN}Starting Locust with Web UI...${NC}"
        echo "  Open http://localhost:8089 in your browser"
        echo ""
        locust -f locustfile.py --host "$HOST"
        ;;
    headless)
        REPORT_NAME="load-test-report-$(date +%Y%m%d-%H%M%S).html"
        echo -e "${GREEN}Running headless load test...${NC}"
        echo "  Report will be saved to: $REPORT_NAME"
        echo ""
        locust -f locustfile.py \
            --host "$HOST" \
            -u "$USERS" \
            -r 5 \
            --run-time "${DURATION}s" \
            --html "$REPORT_NAME" \
            --headless
        echo ""
        echo -e "${GREEN}Test complete! Report: $REPORT_NAME${NC}"
        ;;
    quick)
        echo -e "${GREEN}Running quick test (10 users, 1 minute)...${NC}"
        locust -f locustfile.py \
            --host "$HOST" \
            -u 10 \
            -r 2 \
            --run-time 1m \
            --html "quick-test-$(date +%Y%m%d-%H%M%S).html" \
            --headless
        echo ""
        echo -e "${GREEN}Quick test complete!${NC}"
        ;;
    stress)
        echo -e "${GREEN}Running stress test (100 users, 10 minutes)...${NC}"
        locust -f locustfile.py \
            --host "$HOST" \
            -u 100 \
            -r 10 \
            --run-time 10m \
            --html "stress-test-$(date +%Y%m%d-%H%M%S).html" \
            --headless
        echo ""
        echo -e "${GREEN}Stress test complete!${NC}"
        ;;
    *)
        echo -e "${YELLOW}Usage: $0 [mode]${NC}"
        echo ""
        echo "Modes:"
        echo "  ui        - Start Locust with Web UI (default)"
        echo "  headless  - Run headless with configured settings"
        echo "  quick     - Quick test (10 users, 1 minute)"
        echo "  stress    - Stress test (100 users, 10 minutes)"
        echo ""
        echo "Examples:"
        echo "  $0            # Start with UI"
        echo "  $0 ui         # Start with UI"
        echo "  $0 headless   # Run headless test"
        echo "  $0 quick      # Quick test"
        echo "  $0 stress     # Stress test"
        exit 1
        ;;
esac
