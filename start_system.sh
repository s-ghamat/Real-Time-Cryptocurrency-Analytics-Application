#!/bin/bash

echo "🚀 Démarrage du système Kafka/Spark pour l'app Flutter Crypto"

# Vérifier si l'environnement virtuel existe
if [ ! -d "venv" ]; then
    echo "📦 Création de l'environnement virtuel Python..."
    python3 -m venv venv
    source venv/bin/activate
    pip install kafka-python requests lxml flask flask-cors
else
    echo "✅ Environnement virtuel trouvé"
    source venv/bin/activate
fi

# Démarrer Kafka
echo "🔧 Démarrage de Kafka..."
docker-compose -f docker/docker-compose.kafka.yml up -d

# Attendre que Kafka soit prêt
echo "⏳ Attente du démarrage de Kafka (30 secondes)..."
sleep 30

# Vérifier que Kafka est démarré
echo "🔍 Vérification des services Docker..."
docker ps

# Démarrer le producteur Kafka en arrière-plan
echo "📡 Démarrage du producteur de données Kafka..."
nohup python data-ingestion/kafka_crypto_producer.py > kafka_producer.log 2>&1 &
PRODUCER_PID=$!
echo "Producteur Kafka démarré avec PID: $PRODUCER_PID"

# Attendre un peu pour que le producteur commence à envoyer des données
sleep 10

# Démarrer l'API Gateway
echo "🌐 Démarrage de l'API Gateway..."
nohup python api-gateway/app.py > api_gateway.log 2>&1 &
API_PID=$!
echo "API Gateway démarré avec PID: $API_PID"

echo ""
echo "✅ Système démarré avec succès !"
echo ""
echo "📊 Services disponibles:"
echo "- Kafka UI: http://localhost:8090"
echo "- API Gateway: http://localhost:3000/health"
echo ""
echo "📝 Logs:"
echo "- Producteur Kafka: tail -f kafka_producer.log"
echo "- API Gateway: tail -f api_gateway.log"
echo ""
echo "🛑 Pour arrêter le système:"
echo "kill $PRODUCER_PID $API_PID && docker-compose -f docker/docker-compose.kafka.yml down"
echo ""
echo "🎯 Maintenant vous pouvez lancer l'app Flutter:"
echo "cd crypto_viz_app && flutter run -d linux"
