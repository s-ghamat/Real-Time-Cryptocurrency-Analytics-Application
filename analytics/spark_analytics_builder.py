#!/usr/bin/env python3
"""
Analytics Builder - Spark Streaming avec calculs d'indicateurs techniques et sentiment analysis
"""

import os
import sys
import time
import json
import duckdb
from kafka import KafkaConsumer
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from textblob import TextBlob
import threading
from collections import deque
from email.utils import parsedate_to_datetime

# Import PostgreSQL Writer pour Grafana
try:
    sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'storage'))
    from postgres_writer import PostgreSQLWriter
    POSTGRES_AVAILABLE = True
except ImportError:
    POSTGRES_AVAILABLE = False
    print("⚠️ PostgreSQL Writer non disponible (psycopg2 manquant)")

class SparkAnalyticsBuilder:
    def __init__(self):
        """Initialise l'Analytics Builder avec Spark-like processing"""
        print("🚀 Initialisation de l'Analytics Builder...")
        
        # Configuration Kafka
        # Dans Docker : utiliser le nom du service 'kafka' sur le port 29092
        # Depuis l'hôte Windows : utiliser localhost:9092
        kafka_servers_env = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:29092')
        self.kafka_bootstrap_servers = kafka_servers_env.split(',')[0] if ',' in kafka_servers_env else kafka_servers_env
        self.kafka_topics = ["crypto-prices", "crypto-news"]
        
        # Configuration DuckDB
        self.db_path = "analytics/crypto_analytics.db"
        self.ensure_db_directory()
        
        # Buffers pour le streaming (simule Spark Streaming)
        self.price_buffer = deque(maxlen=1000)  # Buffer pour les prix
        self.news_buffer = deque(maxlen=500)    # Buffer pour les news
        
        # Cache pour les calculs techniques
        self.technical_cache = {}
        
        # Initialiser DuckDB
        self.init_duckdb()
        
        # Initialiser PostgreSQL Writer pour Grafana
        self.postgres_writer = None
        if POSTGRES_AVAILABLE:
            try:
                # Configuration PostgreSQL
                # Dans Docker : utiliser le nom du service 'postgres' sur le port 5432
                # Depuis l'hôte Windows : utiliser 127.0.0.1:5433 (port mappé)
                postgres_host = os.getenv('POSTGRES_HOST', 'postgres')
                postgres_port = int(os.getenv('POSTGRES_PORT', '5432'))
                
                postgres_user = os.getenv('POSTGRES_USER', 'admin')
                postgres_password = os.getenv('POSTGRES_PASSWORD', 'admin')
                
                self.postgres_writer = PostgreSQLWriter(
                    host=postgres_host,
                    port=postgres_port,
                    database='crypto',
                    user=postgres_user,
                    password=postgres_password
                )
                print(f"✅ PostgreSQL Writer initialisé pour Grafana ({postgres_host}:{postgres_port})")
            except Exception as e:
                print(f"⚠️ Impossible d'initialiser PostgreSQL Writer: {e}")
                print(f"   Le consumer continuera sans PostgreSQL (données dans DuckDB uniquement)")
                self.postgres_writer = None
        
        # Créer le consumer Kafka
        self.consumer = KafkaConsumer(
            *self.kafka_topics,
            bootstrap_servers=[self.kafka_bootstrap_servers],
            auto_offset_reset='latest',
            enable_auto_commit=True,
            group_id='analytics-builder-group',
            value_deserializer=lambda x: json.loads(x.decode('utf-8')) if x else None
        )
        
        # Thread pour le traitement en batch
        self.processing_thread = None
        self.stop_processing = False
        
        print("✅ Analytics Builder initialisé avec succès")

    def ensure_db_directory(self):
        """S'assure que le répertoire de la base de données existe"""
        db_dir = os.path.dirname(self.db_path)
        if not os.path.exists(db_dir):
            os.makedirs(db_dir)

    def init_duckdb(self):
        """Initialise les tables DuckDB pour l'analytics"""
        self.conn = duckdb.connect(self.db_path)
        
        # Table pour les prix crypto avec indicateurs techniques
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS crypto_analytics (
                symbol VARCHAR,
                timestamp TIMESTAMP,
                current_price DOUBLE,
                volume_24h DOUBLE,
                price_change_24h DOUBLE,
                price_change_percentage_24h DOUBLE,
                
                -- Indicateurs techniques
                sma_5 DOUBLE,
                sma_10 DOUBLE,
                sma_20 DOUBLE,
                sma_50 DOUBLE,
                ema_12 DOUBLE,
                ema_26 DOUBLE,
                macd DOUBLE,
                macd_signal DOUBLE,
                rsi DOUBLE,
                bollinger_upper DOUBLE,
                bollinger_lower DOUBLE,
                volatility DOUBLE,
                
                -- Signaux de trading
                trend_signal VARCHAR,
                momentum_signal VARCHAR,
                volatility_signal VARCHAR,
                
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (symbol, timestamp)
            )
        """)
        
        # Table pour l'analyse de sentiment des news
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS news_sentiment (
                id VARCHAR PRIMARY KEY,
                title VARCHAR,
                description TEXT,
                url VARCHAR,
                published_at TIMESTAMP,
                source VARCHAR,
                
                -- Sentiment analysis
                sentiment_polarity DOUBLE,  -- -1 (négatif) à 1 (positif)
                sentiment_subjectivity DOUBLE,  -- 0 (objectif) à 1 (subjectif)
                sentiment_label VARCHAR,  -- POSITIVE, NEGATIVE, NEUTRAL
                
                -- Extraction d'entités crypto
                mentioned_cryptos TEXT,  -- JSON array des cryptos mentionnées
                
                processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Table pour les alertes avancées
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS advanced_alerts (
                id INTEGER PRIMARY KEY,
                symbol VARCHAR,
                alert_type VARCHAR,
                message VARCHAR,
                severity VARCHAR,  -- LOW, MEDIUM, HIGH, CRITICAL
                
                -- Données contextuelles
                current_value DOUBLE,
                threshold_value DOUBLE,
                confidence DOUBLE,
                
                -- Métadonnées
                timestamp TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Table pour les métriques de performance
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS performance_metrics (
                timestamp TIMESTAMP PRIMARY KEY,
                total_cryptos_tracked INTEGER,
                total_news_processed INTEGER,
                avg_sentiment_score DOUBLE,
                market_volatility DOUBLE,
                processing_latency_ms DOUBLE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        print("✅ Tables Analytics DuckDB initialisées")

    def calculate_advanced_technical_indicators(self, symbol, prices_df):
        """Calcule des indicateurs techniques avancés"""
        if len(prices_df) < 50:
            return None
            
        prices = prices_df['current_price'].values
        
        # SMAs multiples
        sma_5 = pd.Series(prices).rolling(window=5).mean().iloc[-1] if len(prices) >= 5 else None
        sma_10 = pd.Series(prices).rolling(window=10).mean().iloc[-1] if len(prices) >= 10 else None
        sma_20 = pd.Series(prices).rolling(window=20).mean().iloc[-1] if len(prices) >= 20 else None
        sma_50 = pd.Series(prices).rolling(window=50).mean().iloc[-1] if len(prices) >= 50 else None
        
        # EMAs pour MACD
        ema_12 = pd.Series(prices).ewm(span=12).mean().iloc[-1] if len(prices) >= 12 else None
        ema_26 = pd.Series(prices).ewm(span=26).mean().iloc[-1] if len(prices) >= 26 else None
        
        # MACD
        macd = (ema_12 - ema_26) if ema_12 and ema_26 else None
        macd_signal = pd.Series([macd] * 9).ewm(span=9).mean().iloc[-1] if macd else None
        
        # RSI avancé
        delta = pd.Series(prices).diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = (100 - (100 / (1 + rs))).iloc[-1] if len(gain) >= 14 else None
        
        # Bandes de Bollinger
        sma_20_series = pd.Series(prices).rolling(window=20).mean()
        std_20 = pd.Series(prices).rolling(window=20).std()
        bollinger_upper = (sma_20_series + (std_20 * 2)).iloc[-1] if len(prices) >= 20 else None
        bollinger_lower = (sma_20_series - (std_20 * 2)).iloc[-1] if len(prices) >= 20 else None
        
        # Volatilité
        volatility = std_20.iloc[-1] if len(prices) >= 20 else None
        
        # Signaux de trading
        current_price = prices[-1]
        
        # Signal de tendance
        trend_signal = "BULLISH" if (sma_5 and sma_10 and sma_5 > sma_10) else "BEARISH"
        
        # Signal de momentum
        momentum_signal = "STRONG_BUY" if rsi and rsi < 30 else "STRONG_SELL" if rsi and rsi > 70 else "HOLD"
        
        # Signal de volatilité
        volatility_signal = "HIGH" if volatility and volatility > np.std(prices) * 1.5 else "NORMAL"
        
        return {
            'sma_5': sma_5,
            'sma_10': sma_10,
            'sma_20': sma_20,
            'sma_50': sma_50,
            'ema_12': ema_12,
            'ema_26': ema_26,
            'macd': macd,
            'macd_signal': macd_signal,
            'rsi': rsi,
            'bollinger_upper': bollinger_upper,
            'bollinger_lower': bollinger_lower,
            'volatility': volatility,
            'trend_signal': trend_signal,
            'momentum_signal': momentum_signal,
            'volatility_signal': volatility_signal
        }

    def analyze_sentiment(self, text):
        """Analyse le sentiment d'un texte avec TextBlob"""
        try:
            blob = TextBlob(text)
            polarity = blob.sentiment.polarity
            subjectivity = blob.sentiment.subjectivity
            
            # Classification du sentiment
            if polarity > 0.1:
                label = "POSITIVE"
            elif polarity < -0.1:
                label = "NEGATIVE"
            else:
                label = "NEUTRAL"
            
            return {
                'polarity': polarity,
                'subjectivity': subjectivity,
                'label': label
            }
        except Exception as e:
            print(f"❌ Erreur analyse sentiment: {e}")
            return {'polarity': 0, 'subjectivity': 0, 'label': 'NEUTRAL'}

    def extract_crypto_mentions(self, text):
        """Extrait les mentions de cryptomonnaies dans le texte"""
        crypto_keywords = [
            'bitcoin', 'btc', 'ethereum', 'eth', 'cardano', 'ada',
            'polkadot', 'dot', 'chainlink', 'link', 'litecoin', 'ltc',
            'ripple', 'xrp', 'stellar', 'xlm', 'dogecoin', 'doge',
            'binance', 'bnb', 'solana', 'sol', 'avalanche', 'avax'
        ]
        
        text_lower = text.lower()
        mentioned = [crypto for crypto in crypto_keywords if crypto in text_lower]
        return mentioned

    def generate_advanced_alerts(self, symbol, indicators, current_price):
        """Génère des alertes avancées basées sur les indicateurs"""
        alerts = []
        
        # Alerte MACD crossover
        if indicators.get('macd') and indicators.get('macd_signal'):
            if indicators['macd'] > indicators['macd_signal']:
                alerts.append({
                    'symbol': symbol,
                    'alert_type': 'MACD_BULLISH_CROSSOVER',
                    'message': f'{symbol} MACD croisement haussier détecté',
                    'severity': 'MEDIUM',
                    'current_value': indicators['macd'],
                    'threshold_value': indicators['macd_signal'],
                    'confidence': 0.75
                })
        
        # Alerte Bollinger Bands
        if indicators.get('bollinger_upper') and indicators.get('bollinger_lower'):
            if current_price > indicators['bollinger_upper']:
                alerts.append({
                    'symbol': symbol,
                    'alert_type': 'BOLLINGER_OVERBOUGHT',
                    'message': f'{symbol} prix au-dessus de la bande de Bollinger supérieure',
                    'severity': 'HIGH',
                    'current_value': current_price,
                    'threshold_value': indicators['bollinger_upper'],
                    'confidence': 0.85
                })
            elif current_price < indicators['bollinger_lower']:
                alerts.append({
                    'symbol': symbol,
                    'alert_type': 'BOLLINGER_OVERSOLD',
                    'message': f'{symbol} prix en-dessous de la bande de Bollinger inférieure',
                    'severity': 'HIGH',
                    'current_value': current_price,
                    'threshold_value': indicators['bollinger_lower'],
                    'confidence': 0.85
                })
        
        # Alerte volatilité extrême
        if indicators.get('volatility_signal') == 'HIGH':
            alerts.append({
                'symbol': symbol,
                'alert_type': 'HIGH_VOLATILITY',
                'message': f'{symbol} volatilité élevée détectée',
                'severity': 'MEDIUM',
                'current_value': indicators.get('volatility', 0),
                'threshold_value': 0,
                'confidence': 0.70
            })
        
        return alerts

    def process_price_batch(self):
        """Traite un batch de données de prix (simule Spark micro-batch)"""
        if not self.price_buffer:
            return
        
        # Convertir le buffer en DataFrame
        batch_data = list(self.price_buffer)
        self.price_buffer.clear()
        
        # Grouper par symbole
        symbol_groups = {}
        for data in batch_data:
            symbol = data.get('symbol')
            if symbol not in symbol_groups:
                symbol_groups[symbol] = []
            symbol_groups[symbol].append(data)
        
                # Traiter chaque symbole
        for symbol, symbol_data in symbol_groups.items():
            try:
                print(f"💰 Traitement prix pour {symbol}: {len(symbol_data)} messages")
                # Récupérer l'historique pour les calculs
                historical_data = self.conn.execute("""
                    SELECT current_price, timestamp 
                    FROM crypto_analytics 
                    WHERE symbol = ? 
                    ORDER BY timestamp DESC 
                    LIMIT 100
                """, [symbol]).df()
                
                print(f"📈 Historique disponible pour {symbol}: {len(historical_data)} points")
                
                # Ajouter les nouvelles données
                for data in symbol_data:
                    # Mapping des données du producer Kafka vers le format attendu
                    current_price = data.get('price_usd') or data.get('current_price', 0)
                    volume_24h = data.get('volume_24h_usd') or data.get('total_volume', 0)
                    market_cap = data.get('market_cap_usd') or data.get('market_cap', 0)
                    price_change_24h = data.get('change_24h') or data.get('price_change_percentage_24h', 0)
                    timestamp_now = datetime.now()
                    
                    # Écrire le prix dans PostgreSQL même sans indicateurs
                    if self.postgres_writer:
                        try:
                            self.postgres_writer.write_price(
                                symbol=symbol,
                                price=current_price,
                                volume_24h=volume_24h,
                                market_cap=market_cap,
                                price_change_24h=price_change_24h,
                                timestamp=timestamp_now
                            )
                            print(f"✅ Prix {symbol} écrit dans PostgreSQL: ${current_price:.2f}")
                        except Exception as e:
                            print(f"⚠️ Erreur écriture prix PostgreSQL {symbol}: {e}")
                    
                    # Calculer les indicateurs techniques
                    if len(historical_data) >= 20:
                        # Créer un DataFrame temporaire avec les nouvelles données
                        temp_df = pd.concat([
                            historical_data,
                            pd.DataFrame([{
                                'current_price': current_price,
                                'timestamp': datetime.now()
                            }])
                        ]).sort_values('timestamp')
                        
                        indicators = self.calculate_advanced_technical_indicators(symbol, temp_df)
                        
                        if indicators:
                            print(f"✅ Indicateurs calculés pour {symbol}: RSI={indicators.get('rsi', 'N/A'):.2f}, MACD={indicators.get('macd', 'N/A'):.2f}")
                            timestamp_now = datetime.now()
                            
                            # Insérer dans DuckDB
                            self.conn.execute("""
                                INSERT OR REPLACE INTO crypto_analytics 
                                (symbol, timestamp, current_price, volume_24h, price_change_24h, 
                                 price_change_percentage_24h, sma_5, sma_10, sma_20, sma_50, 
                                 ema_12, ema_26, macd, macd_signal, rsi, bollinger_upper, 
                                 bollinger_lower, volatility, trend_signal, momentum_signal, 
                                 volatility_signal)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            """, (
                                symbol, timestamp_now, current_price,
                                volume_24h, price_change_24h, price_change_24h,
                                indicators['sma_5'], indicators['sma_10'], indicators['sma_20'],
                                indicators['sma_50'], indicators['ema_12'], indicators['ema_26'],
                                indicators['macd'], indicators['macd_signal'], indicators['rsi'],
                                indicators['bollinger_upper'], indicators['bollinger_lower'],
                                indicators['volatility'], indicators['trend_signal'],
                                indicators['momentum_signal'], indicators['volatility_signal']
                            ))
                            
                            # Écrire dans PostgreSQL pour Grafana
                            if self.postgres_writer:
                                try:
                                    # Écrire le prix
                                    self.postgres_writer.write_price(
                                        symbol=symbol,
                                        price=current_price,
                                        volume_24h=volume_24h,
                                        market_cap=market_cap,
                                        price_change_24h=price_change_24h,
                                        timestamp=timestamp_now
                                    )
                                    
                                    # Écrire les indicateurs techniques
                                    self.postgres_writer.write_indicators(
                                        symbol=symbol,
                                        indicators=indicators,
                                        timestamp=timestamp_now
                                    )
                                except Exception as e:
                                    print(f"⚠️ Erreur écriture PostgreSQL: {e}")
                            
                            # Générer des alertes
                            alerts = self.generate_advanced_alerts(symbol, indicators, current_price)
                            for alert in alerts:
                                self.conn.execute("""
                                    INSERT INTO advanced_alerts 
                                    (symbol, alert_type, message, severity, current_value, 
                                     threshold_value, confidence, timestamp)
                                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                                """, (
                                    alert['symbol'], alert['alert_type'], alert['message'],
                                    alert['severity'], alert['current_value'], 
                                    alert['threshold_value'], alert['confidence'], datetime.now()
                                ))
                                print(f"🚨 {alert['severity']}: {alert['message']}")
                            
                            print(f"📊 {symbol}: Prix={current_price:.4f}, RSI={indicators['rsi']:.2f}, Tendance={indicators['trend_signal']}")
                    
            except Exception as e:
                print(f"❌ Erreur traitement batch prix {symbol}: {e}")

    def process_news_batch(self):
        """Traite un batch de données de news avec sentiment analysis"""
        if not self.news_buffer:
            return
        
        batch_data = list(self.news_buffer)
        self.news_buffer.clear()
        
        for data in batch_data:
            try:
                title = data.get('title', '')
                description = data.get('description', '')
                full_text = f"{title} {description}"
                
                # Analyse de sentiment
                sentiment = self.analyze_sentiment(full_text)
                
                # Extraction des cryptos mentionnées
                mentioned_cryptos = self.extract_crypto_mentions(full_text)
                
                # Parser la date correctement
                published_at_str = data.get('published_at', datetime.now().isoformat())
                try:
                    # Essayer d'abord le format RFC 2822 (format RSS)
                    if ',' in published_at_str and '+' in published_at_str:
                        published_at = parsedate_to_datetime(published_at_str)
                    else:
                        # Sinon utiliser le format ISO
                        published_at = datetime.fromisoformat(published_at_str)
                except Exception:
                    # En cas d'échec, utiliser la date actuelle
                    published_at = datetime.now()
                
                # Insérer dans DuckDB
                self.conn.execute("""
                    INSERT OR REPLACE INTO news_sentiment 
                    (id, title, description, url, published_at, source, 
                     sentiment_polarity, sentiment_subjectivity, sentiment_label, 
                     mentioned_cryptos)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    data.get('id', str(hash(title))),
                    title, description, data.get('url'),
                    published_at,
                    data.get('source', 'unknown'),
                    sentiment['polarity'], sentiment['subjectivity'], sentiment['label'],
                    json.dumps(mentioned_cryptos)
                ))
                
                # Écrire dans PostgreSQL pour Grafana
                if self.postgres_writer:
                    try:
                        self.postgres_writer.write_sentiment(
                            source=data.get('source', 'unknown'),
                            sentiment=sentiment['label'],
                            score=sentiment['polarity'],
                            title=title,
                            timestamp=published_at
                        )
                    except Exception as e:
                        print(f"⚠️ Erreur écriture sentiment PostgreSQL: {e}")
                
                print(f"📰 News {sentiment['label']}: {title[:50]}... (Cryptos: {mentioned_cryptos})")
                
            except Exception as e:
                print(f"❌ Erreur traitement news: {e}")

    def batch_processor(self):
        """Thread de traitement en batch (simule Spark Streaming micro-batches)"""
        while not self.stop_processing:
            try:
                # Traiter les batches toutes les 10 secondes
                time.sleep(10)
                
                print("🔄 Traitement des micro-batches...")
                self.process_price_batch()
                self.process_news_batch()
                
                # Mettre à jour les métriques de performance
                self.update_performance_metrics()
                
            except Exception as e:
                print(f"❌ Erreur batch processor: {e}")

    def update_performance_metrics(self):
        """Met à jour les métriques de performance"""
        try:
            # Compter les cryptos trackées
            total_cryptos = self.conn.execute("""
                SELECT COUNT(DISTINCT symbol) FROM crypto_analytics 
                WHERE timestamp > (CURRENT_TIMESTAMP - INTERVAL 1 HOUR)
            """).fetchone()[0]
            
            # Compter les news traitées
            total_news = self.conn.execute("""
                SELECT COUNT(*) FROM news_sentiment 
                WHERE processed_at > (CURRENT_TIMESTAMP - INTERVAL 1 HOUR)
            """).fetchone()[0]
            
            # Sentiment moyen
            avg_sentiment = self.conn.execute("""
                SELECT AVG(sentiment_polarity) FROM news_sentiment 
                WHERE processed_at > (CURRENT_TIMESTAMP - INTERVAL 1 HOUR)
            """).fetchone()[0] or 0
            
            # Volatilité moyenne du marché
            market_volatility = self.conn.execute("""
                SELECT AVG(volatility) FROM crypto_analytics 
                WHERE timestamp > (CURRENT_TIMESTAMP - INTERVAL 1 HOUR) AND volatility IS NOT NULL
            """).fetchone()[0] or 0
            
            # Insérer les métriques
            self.conn.execute("""
                INSERT INTO performance_metrics 
                (timestamp, total_cryptos_tracked, total_news_processed, 
                 avg_sentiment_score, market_volatility, processing_latency_ms)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                datetime.now(), total_cryptos, total_news,
                avg_sentiment, market_volatility, 50.0  # Latence simulée
            ))
            
        except Exception as e:
            print(f"❌ Erreur métriques performance: {e}")

    def start_analytics(self):
        """Démarre l'Analytics Builder"""
        print("🚀 Démarrage de l'Analytics Builder...")
        print("Appuyez sur Ctrl+C pour arrêter")
        
        # Démarrer le thread de traitement en batch
        self.processing_thread = threading.Thread(target=self.batch_processor)
        self.processing_thread.daemon = True
        self.processing_thread.start()
        
        try:
            for message in self.consumer:
                topic = message.topic
                data = message.value
                
                if data is None:
                    continue
                
                # Décoder le JSON si c'est une chaîne de caractères
                if isinstance(data, bytes):
                    import json
                    try:
                        data = json.loads(data.decode('utf-8'))
                    except (json.JSONDecodeError, UnicodeDecodeError) as e:
                        print(f"⚠️ Erreur décodage JSON: {e}")
                        continue
                elif isinstance(data, str):
                    import json
                    try:
                        data = json.loads(data)
                    except json.JSONDecodeError as e:
                        print(f"⚠️ Erreur décodage JSON: {e}")
                        continue
                
                # Ajouter aux buffers pour traitement en batch
                if topic == "crypto-prices":
                    self.price_buffer.append(data)
                elif topic == "crypto-news":
                    self.news_buffer.append(data)
                
                # Commit périodique
                self.consumer.commit()
                
        except KeyboardInterrupt:
            print("\n🛑 Arrêt de l'Analytics Builder demandé")
        except Exception as e:
            print(f"❌ Erreur Analytics Builder: {e}")
        finally:
            self.stop_processing = True
            if self.processing_thread:
                self.processing_thread.join(timeout=5)
            self.consumer.close()
            self.conn.close()
            if self.postgres_writer:
                self.postgres_writer.close()
            print("✅ Analytics Builder arrêté proprement")

if __name__ == "__main__":
    builder = SparkAnalyticsBuilder()
    builder.start_analytics()
