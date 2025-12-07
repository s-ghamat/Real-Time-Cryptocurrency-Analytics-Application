#!/bin/bash

# ============================================================================
# Script d'arrêt du système Crypto Viz
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${YELLOW}🛑 Arrêt du système Crypto Viz...${NC}"
echo ""

# Arrêter les processus Python via PID files
if [ -f .producer.pid ]; then
    PID=$(cat .producer.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo -e "${GREEN}✅ Producteur Kafka arrêté (PID: $PID)${NC}"
    fi
    rm -f .producer.pid
fi

if [ -f .api.pid ]; then
    PID=$(cat .api.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo -e "${GREEN}✅ API Gateway arrêté (PID: $PID)${NC}"
    fi
    rm -f .api.pid
fi

if [ -f .flutter.pid ]; then
    PID=$(cat .flutter.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo -e "${GREEN}✅ Flutter app arrêtée (PID: $PID)${NC}"
    fi
    rm -f .flutter.pid
fi

# Fallback: arrêter via pkill si les PID files n'existent pas
pkill -f kafka_crypto_producer 2>/dev/null || true
pkill -f "python.*app.py" 2>/dev/null || true

# Arrêter les conteneurs Docker (les deux configs)
echo -e "${YELLOW}🐳 Arrêt des conteneurs Docker...${NC}"
docker compose -f docker/docker-compose.kafka.yml down 2>/dev/null || true
docker compose -f docker/docker-compose.full.yml down 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Système arrêté avec succès !${NC}"
echo ""
echo -e "📝 Pour redémarrer:"
echo "   ./start_system.sh           # Mode app (défaut)"
echo "   ./start_system.sh --grafana # Mode Grafana"
echo "   ./start_system.sh --full    # Tout"
