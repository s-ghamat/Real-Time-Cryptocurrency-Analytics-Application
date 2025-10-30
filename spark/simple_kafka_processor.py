#!/usr/bin/env python3
"""
Processeur Kafka-Spark simplifié pour les données crypto
Version sans streaming pour éviter les problèmes de compatibilité Scala
"""

import os
import sys
import time
import json
import duckdb
from kafka import KafkaConsumer
from datetime import datetime
import pandas as pd
import numpy as np

class SimpleCryptoProcessor:
    def __init__(self):
        """Initialise le processeur simple Kafka-DuckDB"""
        print("🚀 Initialisation du processeur Kafka-DuckDB simplifié...")
        
        # Configuration Kafka
        self.kafka_bootstrap_servers = "localhost:9092"
        self.kafka_topics = ["crypto-prices", "crypto-news"]
        
        # Configuration DuckDB
        self.db_path = "storage/crypto_data.db"
        self.ensure_db_directory()
        
        # Initialiser DuckDB
        self.init_duckdb()
        
        # Créer le consumer Kafka
        self.consumer = KafkaConsumer(
            *self.kafka_topics,
            bootstrap_servers=[self.kafka_bootstrap_servers],
            auto_offset_reset='latest',
            enable_auto_commit=True,
            group_id='crypto-processor-group',
            value_deserializer=lambda x: json.loads(x.decode('utf-8')) if x else None
        )
        
        print("✅ Processeur initialisé avec succès")

    def ensure_db_directory(self):
        """S'assure que le répertoire de la base de données existe"""
        db_dir = os.path.dirname(self.db_path)
        if not os.path.exists(db_dir):
            os.makedirs(db_dir)

    def init_duckdb(self):
        """Initialise les tables DuckDB"""
        self.conn = duckdb.connect(self.db_path)
        
        # Table pour les prix crypto
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS crypto_prices (
                id VARCHAR PRIMARY KEY,
                symbol VARCHAR,
                name VARCHAR,
                current_price DOUBLE,
                market_cap DOUBLE,
                market_cap_rank INTEGER,
                price_change_24h DOUBLE,
                price_change_percentage_24h DOUBLE,
                volume_24h DOUBLE,
                timestamp TIMESTAMP,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Table pour les indicateurs techniques
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS technical_indicators (
                symbol VARCHAR,
                timestamp TIMESTAMP,
                sma_20 DOUBLE,
                rsi DOUBLE,
                volatility DOUBLE,
                trend_signal VARCHAR,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (symbol, timestamp)
            )
        """)
        
        # Table pour les alertes
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY,
                symbol VARCHAR,
                alert_type VARCHAR,
                message VARCHAR,
                value DOUBLE,
                threshold DOUBLE,
                timestamp TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Table pour les news crypto
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS crypto_news (
                id VARCHAR PRIMARY KEY,
                title VARCHAR,
                description TEXT,
                url VARCHAR,
                published_at TIMESTAMP,
                source VARCHAR,
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        print("✅ Tables DuckDB initialisées")

    def calculate_technical_indicators(self, symbol, prices_df):
        """Calcule les indicateurs techniques pour un symbole donné"""
        if len(prices_df) < 20:
            return None
            
        # SMA 20 périodes
        sma_20 = prices_df['current_price'].rolling(window=20).mean().iloc[-1]
        
        # RSI simplifié (14 périodes)
        delta = prices_df['current_price'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs)).iloc[-1]
        
        # Volatilité (écart-type des 20 derniers prix)
        volatility = prices_df['current_price'].rolling(window=20).std().iloc[-1]
        
        # Signal de tendance simple
        current_price = prices_df['current_price'].iloc[-1]
        trend_signal = "BUY" if current_price > sma_20 else "SELL"
        
        return {
            'sma_20': sma_20,
            'rsi': rsi,
            'volatility': volatility,
            'trend_signal': trend_signal
        }

    def check_alerts(self, symbol, current_price, rsi):
        """Vérifie et génère des alertes"""
        alerts = []
        
        # Alerte RSI sur-acheté
        if rsi > 70:
            alerts.append({
                'symbol': symbol,
                'alert_type': 'RSI_OVERBOUGHT',
                'message': f'{symbol} RSI sur-acheté: {rsi:.2f}',
                'value': rsi,
                'threshold': 70,
                'timestamp': datetime.now()
            })
        
        # Alerte RSI sur-vendu
        elif rsi < 30:
            alerts.append({
                'symbol': symbol,
                'alert_type': 'RSI_OVERSOLD',
                'message': f'{symbol} RSI sur-vendu: {rsi:.2f}',
                'value': rsi,
                'threshold': 30,
                'timestamp': datetime.now()
            })
        
        return alerts

    def process_crypto_price(self, data):
        """Traite les données de prix crypto"""
        try:
            # Insérer les données de prix
            self.conn.execute("""
                INSERT OR REPLACE INTO crypto_prices 
                (id, symbol, name, current_price, market_cap, market_cap_rank, 
                 price_change_24h, price_change_percentage_24h, volume_24h, timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                data.get('id'),
                data.get('symbol'),
                data.get('name'),
                data.get('current_price'),
                data.get('market_cap'),
                data.get('market_cap_rank'),
                data.get('price_change_24h'),
                data.get('price_change_percentage_24h'),
                data.get('total_volume'),
                datetime.now()
            ))
            
            # Récupérer les 20 derniers prix pour calculer les indicateurs
            symbol = data.get('symbol')
            prices_df = self.conn.execute("""
                SELECT current_price, timestamp 
                FROM crypto_prices 
                WHERE symbol = ? 
                ORDER BY timestamp DESC 
                LIMIT 20
            """, [symbol]).df()
            
            if len(prices_df) >= 20:
                # Calculer les indicateurs techniques
                indicators = self.calculate_technical_indicators(symbol, prices_df)
                
                if indicators:
                    # Insérer les indicateurs
                    self.conn.execute("""
                        INSERT OR REPLACE INTO technical_indicators 
                        (symbol, timestamp, sma_20, rsi, volatility, trend_signal)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, (
                        symbol,
                        datetime.now(),
                        indicators['sma_20'],
                        indicators['rsi'],
                        indicators['volatility'],
                        indicators['trend_signal']
                    ))
                    
                    # Vérifier les alertes
                    alerts = self.check_alerts(symbol, data.get('current_price'), indicators['rsi'])
                    
                    for alert in alerts:
                        self.conn.execute("""
                            INSERT INTO alerts 
                            (symbol, alert_type, message, value, threshold, timestamp)
                            VALUES (?, ?, ?, ?, ?, ?)
                        """, (
                            alert['symbol'],
                            alert['alert_type'],
                            alert['message'],
                            alert['value'],
                            alert['threshold'],
                            alert['timestamp']
                        ))
                        print(f"🚨 ALERTE: {alert['message']}")
                    
                    print(f"📊 {symbol}: Prix={data.get('current_price'):.4f}, RSI={indicators['rsi']:.2f}, Tendance={indicators['trend_signal']}")
            
        except Exception as e:
            print(f"❌ Erreur lors du traitement des prix: {e}")

    def process_crypto_news(self, data):
        """Traite les données de news crypto"""
        try:
            self.conn.execute("""
                INSERT OR REPLACE INTO crypto_news 
                (id, title, description, url, published_at, source)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                data.get('id', str(hash(data.get('title', '')))),
                data.get('title'),
                data.get('description'),
                data.get('url'),
                datetime.fromisoformat(data.get('published_at', datetime.now().isoformat())),
                data.get('source', 'unknown')
            ))
            
            print(f"📰 News ajoutée: {data.get('title', 'Sans titre')[:50]}...")
            
        except Exception as e:
            print(f"❌ Erreur lors du traitement des news: {e}")

    def start_processing(self):
        """Démarre le traitement des messages Kafka"""
        print("🔄 Démarrage du traitement des messages Kafka...")
        print("Appuyez sur Ctrl+C pour arrêter")
        
        try:
            for message in self.consumer:
                topic = message.topic
                data = message.value
                
                if data is None:
                    continue
                
                print(f"📨 Message reçu du topic '{topic}'")
                
                if topic == "crypto-prices":
                    self.process_crypto_price(data)
                elif topic == "crypto-news":
                    self.process_crypto_news(data)
                
                # Commit périodique
                self.consumer.commit()
                
        except KeyboardInterrupt:
            print("\n🛑 Arrêt du processeur demandé par l'utilisateur")
        except Exception as e:
            print(f"❌ Erreur lors du traitement: {e}")
        finally:
            self.consumer.close()
            self.conn.close()
            print("✅ Processeur arrêté proprement")

    def get_stats(self):
        """Affiche les statistiques de la base de données"""
        try:
            # Statistiques des prix
            prices_count = self.conn.execute("SELECT COUNT(*) FROM crypto_prices").fetchone()[0]
            print(f"📊 Nombre de prix stockés: {prices_count}")
            
            # Statistiques des indicateurs
            indicators_count = self.conn.execute("SELECT COUNT(*) FROM technical_indicators").fetchone()[0]
            print(f"📈 Nombre d'indicateurs calculés: {indicators_count}")
            
            # Statistiques des alertes
            alerts_count = self.conn.execute("SELECT COUNT(*) FROM alerts").fetchone()[0]
            print(f"🚨 Nombre d'alertes générées: {alerts_count}")
            
            # Statistiques des news
            news_count = self.conn.execute("SELECT COUNT(*) FROM crypto_news").fetchone()[0]
            print(f"📰 Nombre de news stockées: {news_count}")
            
            # Dernières alertes
            recent_alerts = self.conn.execute("""
                SELECT symbol, alert_type, message, created_at 
                FROM alerts 
                ORDER BY created_at DESC 
                LIMIT 5
            """).fetchall()
            
            if recent_alerts:
                print("\n🚨 Dernières alertes:")
                for alert in recent_alerts:
                    print(f"  - {alert[0]}: {alert[2]} ({alert[3]})")
            
        except Exception as e:
            print(f"❌ Erreur lors de l'affichage des stats: {e}")

if __name__ == "__main__":
    processor = SimpleCryptoProcessor()
    
    # Afficher les stats au démarrage
    processor.get_stats()
    
    # Démarrer le traitement
    processor.start_processing()
