# 📊 Documentation Complète - Système d'Analytics Crypto T-DAT-901

## 🏗️ Architecture Générale du Système

### Vue d'Ensemble
Le projet T-DAT-901 implémente une architecture de streaming de données en temps réel pour l'analyse des cryptomonnaies, combinant plusieurs technologies modernes pour créer un écosystème complet d'analytics.

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Data Sources  │───▶│    Kafka     │───▶│  Spark Stream   │───▶│   Visualisation  │
│  (CoinGecko,    │    │   Broker     │    │   Analytics     │    │   (Streamlit +   │
│   RSS Feeds)    │    │              │    │                 │    │    Flutter)      │
└─────────────────┘    └──────────────┘    └─────────────────┘    └──────────────────┘
                              │                       │                       │
                              ▼                       ▼                       ▼
                       ┌──────────────┐    ┌─────────────────┐    ┌──────────────────┐
                       │ API Gateway  │    │    DuckDB       │    │   Mobile App     │
                       │   (Flask)    │    │   Storage       │    │   (Flutter)      │
                       └──────────────┘    └─────────────────┘    └──────────────────┘
```

---

## 🔧 Composants de l'Architecture

### 1. **Collecte de Données (Data Ingestion)**

#### 📡 Sources de Données
- **CoinGecko API** : Données crypto en temps réel (prix, volumes, market cap)
- **RSS Feeds** : Actualités crypto depuis plusieurs sources françaises
- **Fréquence** : Collecte toutes les 30 secondes

#### 🔄 Producteurs Kafka
**Fichier** : `data-ingestion/kafka_crypto_producer.py`

```python
# Structure des messages Kafka
{
    "timestamp": "2025-01-07T10:30:00Z",
    "symbol": "BTC",
    "price": 45000.50,
    "volume_24h": 28500000000,
    "market_cap": 850000000000,
    "price_change_24h": 2.5
}
```

### 2. **Streaming et Messagerie (Apache Kafka)**

#### 📨 Topics Kafka
- **`crypto-prices`** : Prix et métriques des cryptomonnaies
- **`crypto-news`** : Actualités et sentiment analysis
- **`crypto-alerts`** : Alertes techniques générées

#### ⚙️ Configuration
```yaml
# docker-compose.kafka.yml
- Partitions: 3 par topic
- Replication Factor: 1
- Retention: 7 jours
- Compression: gzip
```

### 3. **Analytics en Temps Réel (Spark-like Processing)**

#### 🧮 Processeur Analytics
**Fichier** : `analytics/spark_analytics_builder.py`

##### Indicateurs Techniques Calculés :

**📈 Simple Moving Average (SMA)**
```python
def calculate_sma(prices, period=20):
    return sum(prices[-period:]) / period
```
- **Usage** : Tendance à moyen terme
- **Période** : 20 périodes par défaut
- **Interprétation** : Prix > SMA = tendance haussière

**📊 Exponential Moving Average (EMA)**
```python
def calculate_ema(prices, period=12):
    multiplier = 2 / (period + 1)
    return (price * multiplier) + (previous_ema * (1 - multiplier))
```
- **Usage** : Réactivité aux changements récents
- **Période** : 12 périodes par défaut
- **Avantage** : Plus sensible que SMA

**⚡ MACD (Moving Average Convergence Divergence)**
```python
macd_line = ema_12 - ema_26
signal_line = ema(macd_line, 9)
histogram = macd_line - signal_line
```
- **Composants** :
  - **MACD Line** : EMA(12) - EMA(26)
  - **Signal Line** : EMA(9) du MACD
  - **Histogram** : MACD - Signal
- **Signaux** :
  - Croisement MACD > Signal = Achat
  - Croisement MACD < Signal = Vente

**🎯 RSI (Relative Strength Index)**
```python
def calculate_rsi(prices, period=14):
    gains = [max(0, prices[i] - prices[i-1]) for i in range(1, len(prices))]
    losses = [max(0, prices[i-1] - prices[i]) for i in range(1, len(prices))]
    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period
    rs = avg_gain / avg_loss if avg_loss != 0 else 0
    return 100 - (100 / (1 + rs))
```
- **Plage** : 0-100
- **Surachat** : RSI > 70
- **Survente** : RSI < 30
- **Neutre** : 30 < RSI < 70

**📏 Bollinger Bands**
```python
def calculate_bollinger_bands(prices, period=20, std_dev=2):
    sma = calculate_sma(prices, period)
    std = standard_deviation(prices[-period:])
    upper_band = sma + (std * std_dev)
    lower_band = sma - (std * std_dev)
    return upper_band, sma, lower_band
```
- **Bande Supérieure** : SMA + (2 × écart-type)
- **Bande Inférieure** : SMA - (2 × écart-type)
- **Usage** : Détection de volatilité et niveaux de support/résistance

#### 🤖 Sentiment Analysis
**Algorithme** : TextBlob pour l'analyse des actualités
```python
def analyze_sentiment(text):
    blob = TextBlob(text)
    polarity = blob.sentiment.polarity  # -1 (négatif) à 1 (positif)
    subjectivity = blob.sentiment.subjectivity  # 0 (objectif) à 1 (subjectif)
    return {
        'sentiment': 'positive' if polarity > 0.1 else 'negative' if polarity < -0.1 else 'neutral',
        'score': polarity,
        'confidence': 1 - subjectivity
    }
```

### 4. **Stockage de Données (DuckDB)**

#### 🗄️ Schéma de Base de Données
```sql
-- Table des prix crypto
CREATE TABLE crypto_prices (
    id INTEGER PRIMARY KEY,
    timestamp TIMESTAMP,
    symbol VARCHAR(10),
    price DECIMAL(18,8),
    volume_24h BIGINT,
    market_cap BIGINT,
    price_change_24h DECIMAL(10,4)
);

-- Table des indicateurs techniques
CREATE TABLE technical_indicators (
    id INTEGER PRIMARY KEY,
    timestamp TIMESTAMP,
    symbol VARCHAR(10),
    sma_20 DECIMAL(18,8),
    ema_12 DECIMAL(18,8),
    ema_26 DECIMAL(18,8),
    macd DECIMAL(18,8),
    macd_signal DECIMAL(18,8),
    rsi DECIMAL(5,2),
    bb_upper DECIMAL(18,8),
    bb_lower DECIMAL(18,8)
);

-- Table des actualités
CREATE TABLE crypto_news (
    id INTEGER PRIMARY KEY,
    timestamp TIMESTAMP,
    title TEXT,
    content TEXT,
    source VARCHAR(100),
    sentiment VARCHAR(20),
    sentiment_score DECIMAL(3,2)
);
```

### 5. **API Gateway (Flask)**

#### 🌐 Endpoints REST
**Fichier** : `api-gateway/app.py`

```python
# Endpoints disponibles
GET  /api/cryptos              # Liste des cryptomonnaies
GET  /api/crypto/{symbol}      # Détails d'une crypto
GET  /api/prices/{symbol}      # Historique des prix
GET  /api/indicators/{symbol}  # Indicateurs techniques
GET  /api/news                 # Actualités crypto
GET  /api/alerts               # Alertes actives
POST /api/alerts               # Créer une alerte
```

**Exemple de réponse** :
```json
{
    "symbol": "BTC",
    "current_price": 45000.50,
    "price_change_24h": 2.5,
    "volume_24h": 28500000000,
    "market_cap": 850000000000,
    "indicators": {
        "sma_20": 44800.25,
        "ema_12": 45100.75,
        "rsi": 65.4,
        "macd": 120.5,
        "sentiment": "positive"
    }
}
```

---

## 📊 Interface de Visualisation

### 1. **Dashboard Streamlit (Web)**

#### 🖥️ Composants du Dashboard
**Fichier** : `dashboard/streamlit_dashboard.py`

##### **Graphique Principal des Prix**
- **Type** : Line Chart interactif (Plotly)
- **Données** : Prix en temps réel avec moyennes mobiles
- **Mise à jour** : Toutes les 30 secondes
- **Indicateurs superposés** :
  - SMA(20) en orange
  - EMA(12) en rouge
  - Bollinger Bands en gris

##### **Graphique RSI**
- **Plage** : 0-100
- **Zones critiques** :
  - Rouge (70-100) : Surachat
  - Vert (0-30) : Survente
  - Gris (30-70) : Zone neutre

##### **Graphique de Volume**
- **Type** : Bar Chart
- **Couleurs** :
  - Vert : Volume en hausse
  - Rouge : Volume en baisse
- **Moyenne** : Ligne de volume moyen sur 20 périodes

##### **Métriques Système**
```python
# Métriques affichées
- Messages Kafka traités/seconde
- Latence moyenne de traitement
- Nombre d'alertes actives
- Statut des services (Kafka, DuckDB, API)
```

### 2. **Application Mobile Flutter**

#### 📱 Architecture Flutter
**Fichiers principaux** :
- `lib/main.dart` : Point d'entrée
- `lib/screens/dark_home_screen.dart` : Écran principal
- `lib/screens/analytics_screen.dart` : Analytics avancés
- `lib/providers/crypto_provider.dart` : Gestion d'état

#### 🎨 Composants Graphiques

##### **Cartes Crypto Enrichies**
```dart
// Structure des données affichées
class CryptoCard {
  String symbol;           // Symbole (BTC, ETH, etc.)
  double currentPrice;     // Prix actuel
  double priceChange24h;   // Variation 24h en %
  double marketCap;        // Capitalisation boursière
  double volume24h;        // Volume 24h
  int marketCapRank;       // Rang par market cap
  List<FlSpot> miniChart;  // Mini graphique 24h
}
```

##### **Graphiques Avancés (Analytics Screen)**

**📈 Graphique de Prix (Line Chart)**
- **Bibliothèque** : fl_chart
- **Données** : 24 points de données simulées
- **Fonctionnalités** :
  - Courbe lissée (isCurved: true)
  - Gradient de remplissage
  - Grille horizontale
  - Axes avec labels formatés

```dart
LineChartData(
  minY: crypto.currentPrice * 0.95,
  maxY: crypto.currentPrice * 1.05,
  lineBarsData: [
    LineChartBarData(
      spots: priceData,
      isCurved: true,
      gradient: LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF357ABD)]),
      belowBarData: BarAreaData(show: true, gradient: ...)
    )
  ]
)
```

**📊 Graphique de Volume (Bar Chart)**
- **Type** : Barres verticales
- **Données** : Volume simulé sur 24h
- **Couleurs** : Gradient bleu
- **Formatage** : Millions (M) et milliards (B)

**⚡ Graphique RSI**
- **Ligne RSI** : Courbe orange
- **Zones critiques** :
  - Ligne rouge à 70 (surachat)
  - Ligne verte à 30 (survente)
- **Indicateurs** : RSI, MACD, Signal affichés en haut

##### **Market Overview Charts**

**🥧 Market Cap (Pie Chart)**
```dart
// Répartition des 8 principales cryptos
PieChartData(
  sections: topCryptos.map((crypto) => 
    PieChartSectionData(
      value: crypto.marketCap,
      title: crypto.symbol,
      color: colors[index],
      radius: 80
    )
  )
)
```

**📈 Performance 24h (Bar Chart)**
- **Données** : Variation % des 10 principales cryptos
- **Couleurs** :
  - Vert : Performance positive
  - Rouge : Performance négative
- **Ligne de référence** : 0% en gris

**👑 Dominance Chart**
- **Type** : Donut chart avec légende
- **Calcul** : `(marketCap_crypto / totalMarketCap) * 100`
- **Affichage** : Top 5 cryptos avec pourcentages

---

## 🔍 Analyse des Données

### 1. **Algorithmes d'Analyse Technique**

#### 📊 Détection de Tendances
```python
def detect_trend(prices, sma_short=10, sma_long=20):
    """
    Détecte la tendance basée sur les moyennes mobiles
    """
    if len(prices) < sma_long:
        return "insufficient_data"
    
    sma_10 = calculate_sma(prices, sma_short)
    sma_20 = calculate_sma(prices, sma_long)
    
    if sma_10 > sma_20:
        return "bullish"  # Tendance haussière
    elif sma_10 < sma_20:
        return "bearish"  # Tendance baissière
    else:
        return "sideways" # Tendance latérale
```

#### 🚨 Système d'Alertes
```python
def generate_alerts(symbol, indicators):
    """
    Génère des alertes basées sur les indicateurs techniques
    """
    alerts = []
    
    # Alerte RSI
    if indicators['rsi'] > 70:
        alerts.append({
            'type': 'RSI_OVERBOUGHT',
            'message': f'{symbol} en zone de surachat (RSI: {indicators["rsi"]:.1f})',
            'severity': 'warning'
        })
    elif indicators['rsi'] < 30:
        alerts.append({
            'type': 'RSI_OVERSOLD',
            'message': f'{symbol} en zone de survente (RSI: {indicators["rsi"]:.1f})',
            'severity': 'opportunity'
        })
    
    # Alerte MACD
    if indicators['macd'] > indicators['macd_signal'] and indicators['macd_prev'] <= indicators['macd_signal_prev']:
        alerts.append({
            'type': 'MACD_BULLISH_CROSS',
            'message': f'{symbol} : Signal d\'achat MACD',
            'severity': 'buy_signal'
        })
    
    return alerts
```

### 2. **Métriques de Performance**

#### ⚡ Latence du Système
- **Collecte → Kafka** : < 100ms
- **Kafka → Analytics** : < 200ms
- **Analytics → Storage** : < 150ms
- **API Response** : < 50ms
- **Total End-to-End** : < 500ms

#### 📈 Throughput
- **Messages Kafka/sec** : 1000+
- **Calculs techniques/sec** : 500+
- **Requêtes API/sec** : 100+
- **Mises à jour UI/sec** : 2 (Streamlit), 1 (Flutter)

---

## 🎯 Interprétation des Graphiques

### 1. **Graphiques de Prix**

#### 📈 Line Charts
**Signification des éléments** :
- **Ligne principale** : Prix actuel de la crypto
- **Zone de remplissage** : Visualisation de la tendance
- **Couleur** :
  - Bleu/Vert : Tendance positive
  - Rouge : Tendance négative
  - Gris : Tendance neutre

**Interprétation** :
- **Pente ascendante** : Momentum haussier
- **Pente descendante** : Momentum baissier
- **Ligne horizontale** : Consolidation/indécision

#### 📊 Candlestick Charts (Simulés)
**Éléments d'une bougie** :
- **Corps** : Différence entre ouverture et clôture
- **Mèches** : Plus haut et plus bas de la période
- **Couleur** :
  - Vert : Clôture > Ouverture (haussier)
  - Rouge : Clôture < Ouverture (baissier)

### 2. **Indicateurs Techniques**

#### 🎯 RSI (Relative Strength Index)
**Zones d'interprétation** :
- **0-30** : Zone de survente (opportunité d'achat potentielle)
- **30-70** : Zone neutre (pas de signal clair)
- **70-100** : Zone de surachat (opportunité de vente potentielle)

**Divergences** :
- **Divergence haussière** : Prix baisse, RSI monte → Retournement possible
- **Divergence baissière** : Prix monte, RSI baisse → Correction possible

#### ⚡ MACD
**Signaux principaux** :
- **Croisement haussier** : MACD > Signal → Signal d'achat
- **Croisement baissier** : MACD < Signal → Signal de vente
- **Histogramme** :
  - Barres croissantes : Momentum s'accélère
  - Barres décroissantes : Momentum ralentit

#### 📏 Bollinger Bands
**Utilisation** :
- **Prix touche bande supérieure** : Possible surachat
- **Prix touche bande inférieure** : Possible survente
- **Bandes resserrées** : Faible volatilité, breakout imminent
- **Bandes élargies** : Forte volatilité

### 3. **Graphiques de Volume**

#### 📊 Volume Bars
**Interprétation** :
- **Volume élevé + prix en hausse** : Confirmation de la tendance haussière
- **Volume élevé + prix en baisse** : Confirmation de la tendance baissière
- **Volume faible** : Manque de conviction, possible retournement
- **Volume croissant** : Intérêt accru des investisseurs

### 4. **Market Overview**

#### 🥧 Market Cap Distribution
**Analyse** :
- **Dominance Bitcoin élevée** : Marché conservateur
- **Dominance Altcoins élevée** : Marché spéculatif
- **Répartition équilibrée** : Marché mature

#### 📈 Performance Comparison
**Lecture** :
- **Barres vertes dominantes** : Marché haussier général
- **Barres rouges dominantes** : Marché baissier général
- **Mixte** : Sélectivité du marché

---

## 🚀 Déploiement et Monitoring

### 1. **Architecture de Déploiement**

#### 🐳 Docker Compose
```yaml
# Services déployés
- Kafka + Zookeeper
- API Gateway (Flask)
- Analytics Processor
- Streamlit Dashboard
- DuckDB (volume persistant)
```

#### 📊 Monitoring
- **Métriques Kafka** : Lag des consumers, throughput
- **Métriques API** : Temps de réponse, taux d'erreur
- **Métriques Analytics** : Temps de calcul, précision
- **Métriques Système** : CPU, RAM, stockage

### 2. **Scalabilité**

#### 📈 Horizontal Scaling
- **Kafka** : Augmentation du nombre de partitions
- **Analytics** : Déploiement de multiples workers
- **API Gateway** : Load balancing avec nginx
- **Storage** : Sharding DuckDB ou migration PostgreSQL

#### ⚡ Optimisations
- **Caching** : Redis pour les données fréquemment accédées
- **Compression** : Gzip pour les messages Kafka
- **Indexation** : Index sur timestamp et symbol dans DuckDB
- **Batch Processing** : Traitement par lots pour les calculs lourds

---

## 📚 Technologies Utilisées

### Backend
- **Apache Kafka** : Streaming de données
- **Python** : Logique métier et analytics
- **Flask** : API REST
- **DuckDB** : Base de données analytique
- **Docker** : Containerisation

### Frontend
- **Streamlit** : Dashboard web interactif
- **Flutter** : Application mobile native
- **Plotly** : Graphiques web interactifs
- **fl_chart** : Graphiques Flutter

### Analytics
- **Pandas** : Manipulation de données
- **NumPy** : Calculs numériques
- **TextBlob** : Sentiment analysis
- **TA-Lib** : Indicateurs techniques (optionnel)

---

## 🎯 Cas d'Usage et Scénarios

### 1. **Trading Algorithmique**
- Utilisation des signaux MACD pour l'entrée/sortie
- Filtrage par RSI pour éviter les faux signaux
- Confirmation par volume pour valider les mouvements

### 2. **Analyse de Sentiment**
- Corrélation entre actualités et mouvements de prix
- Détection d'événements majeurs via pics de sentiment
- Anticipation des retournements de marché

### 3. **Risk Management**
- Alertes automatiques sur niveaux critiques
- Monitoring de la volatilité via Bollinger Bands
- Diversification basée sur la corrélation des actifs

### 4. **Recherche et Backtesting**
- Historique complet pour tests de stratégies
- Métriques de performance détaillées
- Analyse de la précision des indicateurs

---

## 🔧 Configuration et Maintenance

### Variables d'Environnement
```bash
# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_TOPIC_PRICES=crypto-prices
KAFKA_TOPIC_NEWS=crypto-news

# API Configuration
COINGECKO_API_KEY=your_api_key
API_RATE_LIMIT=100
API_PORT=5000

# Database Configuration
DUCKDB_PATH=./crypto_analytics.db
DB_BACKUP_INTERVAL=3600

# Analytics Configuration
TECHNICAL_INDICATORS_PERIOD=20
RSI_PERIOD=14
MACD_FAST=12
MACD_SLOW=26
MACD_SIGNAL=9
```

### Maintenance Régulière
- **Nettoyage des logs** : Rotation automatique
- **Backup DuckDB** : Sauvegarde quotidienne
- **Monitoring des performances** : Alertes sur dégradation
- **Mise à jour des dépendances** : Vérification mensuelle

---

## 📈 Évolutions Futures

### Fonctionnalités Prévues
- **Machine Learning** : Prédiction de prix avec LSTM
- **Alertes personnalisées** : Configuration utilisateur
- **API WebSocket** : Données temps réel pour Flutter
- **Backtesting avancé** : Interface de test de stratégies
- **Multi-exchange** : Intégration Binance, Coinbase Pro
- **Portfolio tracking** : Suivi de portefeuille personnel

### Améliorations Techniques
- **Migration Spark** : Remplacement du processeur custom
- **Kubernetes** : Orchestration cloud-native
- **Monitoring avancé** : Prometheus + Grafana
- **CI/CD** : Pipeline automatisé avec tests
- **Documentation API** : Swagger/OpenAPI

---

*Cette documentation couvre l'ensemble du système d'analytics crypto T-DAT-901. Pour des questions spécifiques ou des clarifications, consultez le code source ou contactez l'équipe de développement.*
