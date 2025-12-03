# 📊 Guide d'Installation et Configuration Grafana

## Vue d'Ensemble

Grafana est intégré dans le système pour fournir une visualisation web ergonomique et professionnelle des données crypto en temps réel. Grafana utilise PostgreSQL comme source de données, qui est alimenté en parallèle avec DuckDB.

## Architecture

```
Kafka → Consumer Python → DuckDB (analytics) + PostgreSQL (Grafana) → Grafana Dashboards
```

## Prérequis

- Docker et Docker Compose installés
- PostgreSQL et Grafana seront démarrés via Docker Compose

## Installation

### 1. Démarrer les Services

```bash
# Démarrer tous les services (Kafka, PostgreSQL, Grafana, etc.)
docker-compose -f docker/docker-compose.full.yml up -d

# Vérifier que les services sont démarrés
docker ps
```

### 2. Vérifier PostgreSQL

```bash
# Vérifier les logs PostgreSQL
docker logs postgres

# Se connecter à PostgreSQL (optionnel)
docker exec -it postgres psql -U admin -d crypto

# Lister les tables
\dt
```

### 3. Accéder à Grafana

- **URL** : http://localhost:3001
- **Username** : `admin`
- **Password** : `admin`

⚠️ **Important** : Changez le mot de passe à la première connexion !

## Configuration Automatique

### Datasource PostgreSQL

La datasource PostgreSQL est configurée automatiquement via provisioning :
- **Host** : `postgres:5432`
- **Database** : `crypto`
- **User** : `admin`
- **Password** : `admin`
- **SSL Mode** : `disable`

Fichier de configuration : `grafana/provisioning/datasources/postgres.yml`

### Dashboards

Les dashboards suivants sont chargés automatiquement :

1. **Crypto Live Prices** (`crypto-live-prices.json`)
   - Prix BTC, ETH, SOL en temps réel
   - Comparaison multi-crypto

2. **Technical Indicators** (`technical-indicators.json`)
   - RSI (Relative Strength Index)
   - MACD (Moving Average Convergence Divergence)
   - Bollinger Bands
   - Variable pour sélectionner le symbole (BTC, ETH, etc.)

3. **Sentiment Analysis** (`sentiment-analysis.json`)
   - Score de sentiment dans le temps
   - Table des articles avec sentiment

4. **Trading Alerts** (`trading-alerts.json`)
   - Alertes RSI > 70 (surachat)
   - Alertes RSI < 30 (survente)
   - Signaux MACD crossover
   - Table des alertes actives

## Démarrage du Consumer avec PostgreSQL

Le consumer `analytics/spark_analytics_builder.py` écrit automatiquement dans PostgreSQL si disponible :

```bash
# Installer les dépendances
pip install -r requirements.txt

# Démarrer le consumer (écrit dans DuckDB ET PostgreSQL)
python analytics/spark_analytics_builder.py
```

Variables d'environnement optionnelles :
```bash
export POSTGRES_HOST=localhost  # Par défaut: localhost
export POSTGRES_PORT=5432       # Par défaut: 5432
```

## Requêtes SQL de Référence

### Prix Crypto

```sql
-- Prix BTC sur la dernière heure
SELECT time AS "time", price 
FROM crypto_prices_grafana 
WHERE symbol = 'BTC' 
ORDER BY time DESC 
LIMIT 100;

-- Comparaison multi-crypto
SELECT time AS "time", price, symbol 
FROM crypto_prices_grafana 
WHERE symbol IN ('BTC', 'ETH', 'SOL') 
ORDER BY time;
```

### Indicateurs Techniques

```sql
-- RSI pour BTC
SELECT time AS "time", rsi 
FROM technical_indicators_grafana 
WHERE symbol = 'BTC' 
ORDER BY time;

-- MACD pour BTC
SELECT time AS "time", macd AS "MACD Line", macd_signal AS "Signal Line" 
FROM technical_indicators_grafana 
WHERE symbol = 'BTC' 
ORDER BY time;

-- Bollinger Bands pour BTC
SELECT time AS "time", bb_upper AS "Upper", sma_20 AS "SMA 20", bb_lower AS "Lower" 
FROM technical_indicators_grafana 
WHERE symbol = 'BTC' 
ORDER BY time;
```

### Sentiment Analysis

```sql
-- Score de sentiment dans le temps
SELECT time AS "time", score 
FROM crypto_sentiment_grafana 
ORDER BY time;

-- Derniers articles avec sentiment
SELECT time AS "Time", title, source, sentiment, score 
FROM crypto_sentiment_grafana 
ORDER BY time DESC 
LIMIT 50;
```

### Alertes Trading

```sql
-- Cryptos en surachat (RSI > 70)
SELECT symbol, time, rsi 
FROM technical_indicators_grafana 
WHERE rsi > 70 
ORDER BY time DESC;

-- Cryptos en survente (RSI < 30)
SELECT symbol, time, rsi 
FROM technical_indicators_grafana 
WHERE rsi < 30 
ORDER BY time DESC;
```

## Personnalisation des Dashboards

### Ajouter un Nouveau Panel

1. Ouvrir Grafana : http://localhost:3001
2. Aller dans un dashboard existant
3. Cliquer sur "Add" → "Visualization"
4. Sélectionner "PostgreSQL" comme datasource
5. Écrire votre requête SQL
6. Configurer la visualisation

### Créer un Nouveau Dashboard

1. Dans Grafana : "+" → "Create" → "Dashboard"
2. Ajouter des panels avec des requêtes PostgreSQL
3. Exporter le dashboard en JSON
4. Sauvegarder dans `grafana/dashboards/`
5. Le dashboard sera chargé automatiquement au prochain démarrage

## Troubleshooting

### Grafana ne démarre pas

```bash
# Vérifier les logs
docker logs grafana

# Vérifier que PostgreSQL est démarré
docker ps | grep postgres
```

### Pas de données dans Grafana

1. **Vérifier que le consumer écrit dans PostgreSQL** :
   ```bash
   # Vérifier les logs du consumer
   python analytics/spark_analytics_builder.py
   # Vous devriez voir : "✅ PostgreSQL Writer initialisé pour Grafana"
   ```

2. **Vérifier les données dans PostgreSQL** :
   ```bash
   docker exec -it postgres psql -U admin -d crypto
   SELECT COUNT(*) FROM crypto_prices_grafana;
   SELECT COUNT(*) FROM technical_indicators_grafana;
   ```

3. **Vérifier la datasource dans Grafana** :
   - Configuration → Data Sources → PostgreSQL
   - Tester la connexion

### Erreur "psycopg2 not found"

```bash
# Installer psycopg2-binary
pip install psycopg2-binary>=2.9.0
```

### Les dashboards ne se chargent pas

1. Vérifier les permissions des fichiers :
   ```bash
   ls -la grafana/dashboards/
   ```

2. Vérifier les logs Grafana :
   ```bash
   docker logs grafana | grep -i dashboard
   ```

3. Redémarrer Grafana :
   ```bash
   docker restart grafana
   ```

## Ports Utilisés

| Service | Port | URL |
|---------|------|-----|
| Grafana | 3001 | http://localhost:3001 |
| PostgreSQL | 5432 | localhost:5432 |
| API Gateway | 3000 | http://localhost:3000 |
| Kafka UI | 8090 | http://localhost:8090 |

## Sécurité

⚠️ **Important pour la production** :

1. **Changer les mots de passe par défaut** :
   - Grafana : admin/admin → changer via l'interface
   - PostgreSQL : modifier dans `docker-compose.full.yml`

2. **Activer SSL** :
   - Configurer SSL pour PostgreSQL
   - Configurer HTTPS pour Grafana

3. **Restreindre l'accès** :
   - Utiliser un reverse proxy (nginx)
   - Configurer l'authentification LDAP/OAuth dans Grafana

## Performance

### Optimisations Recommandées

1. **Index PostgreSQL** : Déjà créés automatiquement sur `time` et `symbol`
2. **Rétention des données** : Configurer une politique de nettoyage si nécessaire
3. **Refresh rate** : Ajuster selon vos besoins (défaut : 10-30s)

### Nettoyage des Données Anciennes

```sql
-- Supprimer les données de plus de 7 jours (exemple)
DELETE FROM crypto_prices_grafana 
WHERE time < NOW() - INTERVAL '7 days';

DELETE FROM technical_indicators_grafana 
WHERE time < NOW() - INTERVAL '7 days';
```

## Support

Pour plus d'informations :
- Documentation Grafana : https://grafana.com/docs/
- Documentation PostgreSQL : https://www.postgresql.org/docs/


