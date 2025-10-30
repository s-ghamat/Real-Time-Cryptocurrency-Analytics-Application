# T-DAT-901 - Xtreme Dashboarding

## 🎯 Mission
Système de monitoring big data pour analyser les flux d'actualités cryptomonnaies en temps réel.

## 📋 Objectifs
1. **Collecte Continue** - Flux d'actualités cryptomonnaies
2. **Traitement Temps Réel** - Analytics avec Apache Spark
3. **Visualisation Dynamique** - Dashboard interactif

## 🏗️ Architecture
```
[Data Sources] → [Kafka] → [Spark] → [Storage] → [Dashboard]
```

## 🛠️ Technologies
- **Apache Kafka** - Streaming de données
- **Apache Spark** - Traitement big data
- **Docker** - Conteneurisation
- **Python** - Scripts de scraping et analyse
- **Grafana/Plotly** - Visualisation

## 📁 Structure du projet
```
├── data-ingestion/     # Scripts de collecte de données
├── kafka/             # Configuration Kafka
├── spark/             # Jobs Spark pour le traitement
├── storage/           # Base de données et stockage
├── dashboard/         # Interface de visualisation
├── docker/            # Configurations Docker
└── docs/              # Documentation
```
