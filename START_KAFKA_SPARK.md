# 🚀 Démarrage du Pipeline Kafka/Spark pour l'App Flutter Crypto

## Architecture Complète
```
[APIs Crypto] → [Kafka Producer] → [Kafka Topics] → [Spark Processing] → [API Gateway] → [Flutter App]
```

## 📋 Étapes de Démarrage

### 1. Démarrer l'infrastructure Kafka/Spark
```bash
cd /home/lekrikri/Projects/T-DAT-901-PAR_10

# Démarrer Kafka + Spark + API Gateway
docker-compose -f docker/docker-compose.full.yml up -d

# Vérifier que tous les services sont démarrés
docker ps
```

### 2. Vérifier les services
- **Kafka UI**: http://localhost:8090
- **Spark Master**: http://localhost:8080  
- **API Gateway**: http://localhost:3000/health

### 3. Démarrer le producteur de données
```bash
# Dans un nouveau terminal
cd /home/lekrikri/Projects/T-DAT-901-PAR_10
python data-ingestion/kafka_crypto_producer.py
```

### 4. Lancer l'application Flutter
```bash
cd crypto_viz_app
flutter run -d linux
```

## 🔍 Monitoring

### Topics Kafka créés automatiquement:
- `crypto-prices` - Prix des cryptomonnaies en temps réel
- `crypto-news` - Actualités crypto françaises  
- `crypto-alerts` - Alertes de prix
- `processed-data` - Données traitées par Spark

### API Gateway Endpoints:
- `GET /api/crypto/prices` - Prix depuis Kafka stream
- `GET /api/crypto/news` - News depuis Kafka stream  
- `GET /api/crypto/trending` - Cryptos tendance
- `GET /api/stats` - Statistiques du marché

## 🛠️ Résolution de problèmes

### Si Kafka ne démarre pas:
```bash
# Nettoyer les volumes Docker
docker-compose -f docker/docker-compose.full.yml down -v
docker system prune -f
```

### Si l'API Gateway ne répond pas:
```bash
# Vérifier les logs
docker logs api-gateway
```

### Si Flutter ne trouve pas l'API:
- Vérifier que l'API Gateway est sur http://localhost:3000
- Tester: `curl http://localhost:3000/health`

## 📊 Flux de Données

1. **Collecte**: Le producteur Kafka collecte depuis CoinGecko, RSS français
2. **Stream**: Les données sont envoyées vers les topics Kafka  
3. **Processing**: Spark traite les données (moyennes, tendances)
4. **API**: L'API Gateway expose les données via REST
5. **Flutter**: L'app consomme les données en temps réel

## 🎯 Avantages de cette Architecture

- ✅ **Temps réel**: Données crypto live toutes les 30 secondes
- ✅ **Scalabilité**: Kafka + Spark peuvent traiter des millions d'événements
- ✅ **Résilience**: Fallback vers CoinGecko si Kafka est indisponible  
- ✅ **Monitoring**: Interface Kafka UI pour surveiller les flux
- ✅ **Français**: Actualités depuis Journal du Coin, Cryptoast, CoinTribune
