#!/bin/bash

# LocalStack Fix Script - Resolves common startup issues

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   LocalStack Fix & Clean Start         ║"
echo "╚════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/../docker"

# Step 1: Stop everything
echo -e "${BLUE}Step 1: Stopping LocalStack...${NC}"
docker-compose down -v 2>/dev/null
echo -e "${GREEN}✓ Stopped${NC}"
echo ""

# Step 2: Clean up
echo -e "${BLUE}Step 2: Cleaning up Docker...${NC}"
docker ps -a | grep localstack | awk '{print $1}' | xargs docker rm -f 2>/dev/null || true
docker volume ls | grep localstack | awk '{print $2}' | xargs docker volume rm 2>/dev/null || true
echo -e "${GREEN}✓ Cleaned${NC}"
echo ""

# Step 3: Check port
echo -e "${BLUE}Step 3: Checking port 4566...${NC}"
if lsof -i :4566 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Port 4566 is in use${NC}"
    echo "Processes using port 4566:"
    lsof -i :4566
    echo ""
    read -p "Kill these processes? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti :4566 | xargs kill -9 2>/dev/null || true
        echo -e "${GREEN}✓ Processes killed${NC}"
    fi
else
    echo -e "${GREEN}✓ Port 4566 is free${NC}"
fi
echo ""

# Step 4: Start LocalStack
echo -e "${BLUE}Step 4: Starting LocalStack...${NC}"
docker-compose up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Container started${NC}"
else
    echo -e "${RED}✗ Failed to start${NC}"
    echo "Check docker-compose logs for details"
    exit 1
fi
echo ""

# Step 5: Wait for initialization
echo -e "${BLUE}Step 5: Waiting for LocalStack to initialize...${NC}"
echo "This may take 20-30 seconds..."
sleep 25

# Step 6: Health check
echo -e "${BLUE}Step 6: Checking health...${NC}"
if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ LocalStack is healthy!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ LocalStack is ready!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Test it:"
    echo "  aws --endpoint-url=http://localhost:4566 s3 ls"
    echo ""
    echo "Or install awslocal:"
    echo "  pip install awscli-local"
    echo "  awslocal s3 ls"
    echo ""
else
    echo -e "${YELLOW}⚠ LocalStack not responding yet${NC}"
    echo "Wait a bit longer, then check logs:"
    echo "  docker-compose logs -f"
fi
echo ""

# Step 7: Show status
echo -e "${BLUE}Container Status:${NC}"
docker-compose ps
echo ""

echo "To view logs: docker-compose logs -f"
echo "To stop: docker-compose down"
echo ""
