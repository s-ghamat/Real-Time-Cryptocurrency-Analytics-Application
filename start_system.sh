#!/bin/bash

# ============================================================================
# Script de démarrage du système Crypto Viz
# ============================================================================
# Usage:
#   ./start_system.sh           # Mode par défaut (--app)
#   ./start_system.sh --app     # Lance Kafka + Producer + API + Flutter
#   ./start_system.sh --grafana # Lance Kafka + PostgreSQL + Grafana (visualisation web)
#   ./start_system.sh --full    # Lance tout (app Flutter + Grafana)
# ============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Mode par défaut
MODE="app"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app)
            MODE="app"
            shift
            ;;
        --grafana)
            MODE="grafana"
            shift
            ;;
        --full)
            MODE="full"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --app      Lance Kafka + API Gateway + Flutter app (défaut)"
            echo "  --grafana  Lance Kafka + PostgreSQL + Grafana (visualisation web)"
            echo "  --full     Lance tout (Flutter app + Grafana)"
            echo "  --help     Affiche cette aide"
            exit 0
            ;;
        *)
            echo -e "${RED}Option inconnue: $1${NC}"
            echo "Utilisez --help pour voir les options disponibles"
            exit 1
            ;;
    esac
done

# Affichage de l'encadré (sans emojis pour éviter les décalages)
echo -e "${BLUE}+------------------------------------------------------------+${NC}"
echo -e "${BLUE}|           Crypto Viz - Demarrage du systeme                |${NC}"
printf "${BLUE}|                    Mode: ${GREEN}%-7s${BLUE}                         |${NC}\n" "$MODE"
echo -e "${BLUE}+------------------------------------------------------------+${NC}"
echo ""

# ============================================================================
# Fonction: Setup de l'environnement Python
# ============================================================================
setup_python_env() {
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}📦 Création de l'environnement virtuel Python...${NC}"
        python3 -m venv venv
        source venv/bin/activate
        echo -e "${YELLOW}📦 Installation des dépendances Python...${NC}"
        pip install --upgrade pip
        pip install kafka-python requests lxml flask flask-cors pyspark certifi psycopg2-binary
    else
        echo -e "${GREEN}✅ Environnement virtuel trouvé${NC}"
        source venv/bin/activate
    fi
}

# ============================================================================
# Fonction: Démarrer les conteneurs Docker
# ============================================================================
start_docker_services() {
    local compose_file=$1
    echo -e "${YELLOW}🐳 Démarrage des services Docker ($compose_file)...${NC}"
    docker compose -f "docker/$compose_file" up -d

    echo -e "${YELLOW}⏳ Attente du démarrage des services (30 secondes)...${NC}"
    sleep 30

    echo -e "${GREEN}🔍 Services Docker actifs:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(kafka|zoo|grafana|postgres|api|collector|analytics)" || true
}

# ============================================================================
# Fonction: Démarrer le producteur Kafka
# ============================================================================
start_kafka_producer() {
    echo -e "${YELLOW}📡 Démarrage du producteur de données Kafka...${NC}"
    nohup python data-ingestion/kafka_crypto_producer.py > kafka_producer.log 2>&1 &
    PRODUCER_PID=$!
    echo $PRODUCER_PID > .producer.pid
    echo -e "${GREEN}   Producteur Kafka démarré (PID: $PRODUCER_PID)${NC}"
    sleep 5
}

# ============================================================================
# Fonction: Démarrer l'API Gateway
# ============================================================================
start_api_gateway() {
    echo -e "${YELLOW}🌐 Démarrage de l'API Gateway...${NC}"
    nohup python api-gateway/app.py > api_gateway.log 2>&1 &
    API_PID=$!
    echo $API_PID > .api.pid
    echo -e "${GREEN}   API Gateway démarré (PID: $API_PID)${NC}"
    sleep 3
}

# ============================================================================
# Fonction: Lancer l'app Flutter
# ============================================================================
launch_flutter_app() {
    echo -e "${YELLOW}📱 Lancement de l'application Flutter...${NC}"
    cd crypto_viz_app
    flutter run -d linux
    cd ..
}

# ============================================================================
# Fonction: Ouvrir Grafana dans le navigateur
# ============================================================================
open_grafana() {
    echo -e "${YELLOW}🌐 Ouverture de Grafana dans le navigateur...${NC}"
    sleep 5  # Attendre que Grafana soit prêt

    # Détecter la commande pour ouvrir le navigateur selon l'OS
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:3001" &
    elif command -v open &> /dev/null; then
        open "http://localhost:3001" &
    elif command -v start &> /dev/null; then
        start "http://localhost:3001" &
    else
        echo -e "${YELLOW}   Ouvre manuellement: http://localhost:3001${NC}"
    fi

    echo -e "${GREEN}   Grafana: http://localhost:3001 (admin/admin)${NC}"
}

# ============================================================================
# Fonction: Afficher le résumé
# ============================================================================
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✅ Système démarré avec succès !              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}📊 Services disponibles:${NC}"
    echo "   - Kafka UI:     http://localhost:8090"

    if [[ "$MODE" == "app" || "$MODE" == "full" ]]; then
        echo "   - API Gateway:  http://localhost:3000/health"
    fi

    if [[ "$MODE" == "grafana" || "$MODE" == "full" ]]; then
        echo "   - Grafana:      http://localhost:3001 (admin/admin)"
        echo "   - PostgreSQL:   localhost:5433 (admin/admin)"
    fi

    echo ""
    echo -e "${BLUE}📝 Logs:${NC}"
    echo "   - Producteur Kafka: tail -f kafka_producer.log"
    echo "   - API Gateway:      tail -f api_gateway.log"
    echo ""
    echo -e "${BLUE}🛑 Pour arrêter le système:${NC}"
    echo "   ./stop_system.sh"
    echo ""
}

# ============================================================================
# MAIN: Exécution selon le mode
# ============================================================================

case $MODE in
    app)
        # Mode APP: Kafka + Producer + API + Flutter
        setup_python_env
        start_docker_services "docker-compose.kafka.yml"
        start_kafka_producer
        start_api_gateway
        show_summary
        launch_flutter_app
        ;;

    grafana)
        # Mode GRAFANA: Full stack sans Flutter
        setup_python_env
        start_docker_services "docker-compose.full.yml"
        show_summary
        open_grafana
        ;;

    full)
        # Mode FULL: Tout
        setup_python_env
        start_docker_services "docker-compose.full.yml"
        start_kafka_producer
        start_api_gateway
        show_summary
        open_grafana
        launch_flutter_app
        ;;
esac

echo ""
