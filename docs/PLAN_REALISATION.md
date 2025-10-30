# T-DAT-901 - PLAN DE RÉALISATION DÉTAILLÉ
## Application Mobile de Streaming Crypto en Temps Réel

---

## 🎯 **OBJECTIF PRINCIPAL**
Créer une application mobile de streaming pour visualiser les cours des cryptomonnaies en temps réel, en utilisant les technologies Big Data (pandas, DuckDB, Apache Spark).

---

## 📋 **ÉTAPES DE RÉALISATION**

### **PHASE 1 : PRÉPARATION DE L'ENVIRONNEMENT** ⏱️ *2-3 jours*

#### **1.1 Installation des outils de base**
- [ ] **Python 3.9+** avec pip
- [ ] **Git** (déjà configuré ✅)
- [ ] **Docker & Docker Compose**
- [ ] **WSL2** (si sur Windows)

#### **1.2 Installation des bibliothèques Python**
```bash
pip install pandas>=2.0.0
pip install duckdb==0.8.0
pip install pyspark>=3.4.0
pip install streamlit
pip install plotly
pip install requests
```

#### **1.3 Configuration Docker pour Spark**
- [ ] Créer le réseau Docker : `docker network create -d bridge spark-experiment`
- [ ] Tester l'image Bitnami Spark
- [ ] Vérifier l'accès à l'interface web Spark (localhost:8080)

---

### **PHASE 2 : COLLECTE ET STOCKAGE DES DONNÉES** ⏱️ *3-4 jours*

#### **2.1 Exploration des données avec pandas**
- [ ] **Télécharger un dataset crypto** (ex: données historiques Bitcoin)
- [ ] **Analyser avec pandas** :
  ```python
  import pandas as pd
  df = pd.read_csv("crypto_data.csv", chunksize=10000)
  df.describe()
  ```
- [ ] **Identifier les colonnes importantes** : timestamp, symbol, price, volume

#### **2.2 Configuration DuckDB**
- [ ] **Installer DuckDB** : `pip install duckdb==0.8.0`
- [ ] **Créer la base de données** :
  ```python
  import duckdb as ddb
  con = ddb.connect("crypto-database.db")
  con.sql("CREATE TABLE crypto_prices AS SELECT * FROM read_csv('crypto_data.csv')")
  ```
- [ ] **Tester import/export Parquet** pour optimisation

#### **2.3 Collecte de données en temps réel**
- [ ] **API CoinGecko** (gratuite) : `https://api.coingecko.com/api/v3/`
  - 18,000+ cryptos vs 2,000 sur Binance
  - 50 calls/minute gratuit
  - Données market cap, volume global, trending
- [ ] **Script de collecte automatique** toutes les 30 secondes
- [ ] **Stockage dans DuckDB** en continu

---

### **PHASE 3 : TRAITEMENT AVEC APACHE SPARK** ⏱️ *4-5 jours*

#### **3.1 Configuration du cluster Spark**
- [ ] **Démarrer le master** :
  ```bash
  docker run -v "$PWD:/opt/bitnami/spark/work" -e SPARK_MODE=master \
    -p 8080:8080 --network spark-experiment bitnami/spark:latest
  ```
- [ ] **Ajouter 2-3 workers** :
  ```bash
  docker run -v "$PWD:/opt/bitnami/spark/work" -e SPARK_MODE=worker \
    -e SPARK_MASTER_URL="spark://MASTER_URL:7077" \
    --network spark-experiment bitnami/spark:latest
  ```

#### **3.2 Développement des jobs Spark**
- [ ] **Job d'analyse des prix** (variations, moyennes)
- [ ] **Détection des tendances** (hausse/baisse)
- [ ] **Calcul des indicateurs techniques** (RSI, moyennes mobiles)
- [ ] **Test avec l'exemple WordCount** adapté aux cryptos

#### **3.3 Traitement en temps réel**
- [ ] **Spark Streaming** pour données live
- [ ] **Agrégations par fenêtres temporelles** (1min, 5min, 1h)
- [ ] **Alertes automatiques** sur variations importantes

---

### **PHASE 4 : APPLICATION MOBILE NATIVE** ⏱️ *7-8 jours*

#### **4.1 Choix technologique : Flutter (recommandé)**
- [ ] **Installation Flutter SDK** et Android Studio
- [ ] **Création projet Flutter** : `flutter create crypto_viz_app`
- [ ] **Configuration des dépendances** : http, charts_flutter, websocket

#### **4.2 Alternative : React Native**
- [ ] **Installation React Native CLI** : `npm install -g react-native-cli`
- [ ] **Création projet** : `react-native init CryptoVizApp`
- [ ] **Dépendances** : axios, react-native-charts, websocket

#### **4.3 Option PWA (plus simple)**
- [ ] **React + Vite** pour PWA mobile-optimisée
- [ ] **Service Worker** pour fonctionnement offline
- [ ] **Manifest.json** pour installation sur mobile

#### **4.2 Fonctionnalités avancées**
- [ ] **Graphiques interactifs** :
  - Prix en temps réel (line chart)
  - Variations 24h (bar chart)
  - Volume de trading (pie chart)
- [ ] **Alertes personnalisées** (seuils de prix)
- [ ] **Historique des performances**

#### **4.3 Optimisation mobile**
- [ ] **Design responsive** pour smartphones
- [ ] **Mise à jour automatique** toutes les 10 secondes
- [ ] **Mode sombre/clair**
- [ ] **Notifications push** (optionnel)

---

### **PHASE 5 : INTÉGRATION ET TESTS** ⏱️ *2-3 jours*

#### **5.1 Pipeline complet**
- [ ] **Collecte** → **DuckDB** → **Spark** → **Streamlit**
- [ ] **Tests de charge** (simulation 1000+ utilisateurs)
- [ ] **Optimisation des performances**

#### **5.2 Documentation et déploiement**
- [ ] **README complet** avec instructions d'installation
- [ ] **Docker Compose** pour déploiement facile
- [ ] **Tests sur différents appareils** (mobile, tablette, desktop)

---

## 🛠️ **ARCHITECTURE TECHNIQUE**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   APIs Crypto   │───▶│     DuckDB      │───▶│  Apache Spark   │
│  (Binance, etc) │    │   (Stockage)    │    │  (Traitement)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  App Mobile     │◀───│   Streamlit     │◀───│   Résultats     │
│  (Interface)    │    │   (Dashboard)   │    │   Analysés      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## 📅 **PLANNING PRÉVISIONNEL**

| Phase | Durée | Tâches principales |
|-------|-------|-------------------|
| **Phase 1** | 2-3 jours | Installation environnement |
| **Phase 2** | 3-4 jours | Collecte et stockage données |
| **Phase 3** | 4-5 jours | Traitement Spark |
| **Phase 4** | 5-6 jours | Application mobile |
| **Phase 5** | 2-3 jours | Tests et déploiement |
| **TOTAL** | **16-21 jours** | **Projet complet** |

---

## 🎯 **LIVRABLES ATTENDUS**

1. **Application mobile fonctionnelle** avec interface Streamlit
2. **Pipeline de données** automatisé (collecte → traitement → visualisation)
3. **Cluster Spark** configuré avec jobs d'analyse
4. **Base DuckDB** optimisée avec données historiques
5. **Documentation complète** d'installation et d'utilisation
6. **Code source** versionné sur GitHub

---

## 🚀 **CRITÈRES DE SUCCÈS**

- ✅ **Données temps réel** : Mise à jour toutes les 10 secondes
- ✅ **Performance** : Traitement de 1000+ points de données/minute
- ✅ **Interface mobile** : Responsive sur smartphone/tablette
- ✅ **Analyse avancée** : Indicateurs techniques calculés par Spark
- ✅ **Stabilité** : Fonctionnement 24h/24 sans interruption

---

## 📚 **RESSOURCES NÉCESSAIRES**

### **APIs de données**
- Binance API (gratuite) : `https://api.binance.com/`
- CoinGecko API (gratuite) : `https://api.coingecko.com/`

### **Documentation technique**
- Pandas : `https://pandas.pydata.org/docs/`
- DuckDB : `https://duckdb.org/docs/`
- Apache Spark : `https://spark.apache.org/docs/`
- Streamlit : `https://docs.streamlit.io/`

### **Ressources matérielles**
- **RAM** : 8GB minimum (16GB recommandé)
- **CPU** : 4 cores minimum
- **Stockage** : 50GB d'espace libre
- **Réseau** : Connexion stable pour APIs
