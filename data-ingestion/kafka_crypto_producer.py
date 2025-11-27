#!/usr/bin/env python3
"""
Producteur Kafka pour données crypto
Collecte et envoie les données vers Kafka
"""

import json
import time
import requests
import logging
from datetime import datetime
from kafka import KafkaProducer
from kafka.errors import KafkaError
import xml.etree.ElementTree as ET

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CryptoKafkaProducer:
    def __init__(self, kafka_servers=['localhost:9092']):
        """Initialise le producteur Kafka"""
        self.producer = KafkaProducer(
            bootstrap_servers=kafka_servers,
            value_serializer=lambda x: json.dumps(x).encode('utf-8'),
            key_serializer=lambda x: x.encode('utf-8') if x else None
        )
        
        # Topics Kafka
        self.topics = {
            'prices': 'crypto-prices',
            'news': 'crypto-news',
            'alerts': 'crypto-alerts'
        }
        
        # URLs des APIs
        self.apis = {
            'coingecko': 'https://api.coingecko.com/api/v3',
            'binance': 'https://api.binance.com/api/v3',
            'journalducoin': 'https://journalducoin.com/feed/',
            'cryptoast': 'https://cryptoast.fr/feed/',
            'cointribune': 'https://www.cointribune.com/feed/'
        }
        
        # Cryptos à surveiller
        self.crypto_symbols = ['bitcoin', 'ethereum', 'solana', 'cardano', 'polkadot']
        
    def collect_crypto_prices(self):
        """Collecte les prix des cryptomonnaies depuis Binance (gratuit, sans limite)"""
        try:
            # Map des symboles vers les paires Binance
            binance_pairs = {
                'bitcoin': 'BTCUSDT',
                'ethereum': 'ETHUSDT',
                'solana': 'SOLUSDT',
                'cardano': 'ADAUSDT',
                'polkadot': 'DOTUSDT'
            }

            timestamp = datetime.now().isoformat()
            collected = 0

            for crypto_name, pair in binance_pairs.items():
                try:
                    # Binance price ticker
                    price_url = f"{self.apis['binance']}/ticker/24hr?symbol={pair}"
                    response = requests.get(price_url, timeout=5)

                    if response.status_code == 200:
                        data = response.json()

                        price_data = {
                            'timestamp': timestamp,
                            'symbol': crypto_name,
                            'price_usd': float(data.get('lastPrice', 0)),
                            'price_eur': float(data.get('lastPrice', 0)) * 0.92,  # Approximation EUR
                            'market_cap_usd': 0,  # Binance ne fournit pas market cap
                            'volume_24h_usd': float(data.get('volume', 0)) * float(data.get('lastPrice', 0)),
                            'change_24h': float(data.get('priceChangePercent', 0)),
                            'source': 'binance'
                        }

                        # Envoie vers Kafka
                        self.send_to_kafka(self.topics['prices'], crypto_name, price_data)
                        collected += 1

                except Exception as e:
                    logger.warning(f"Erreur pour {crypto_name}: {e}")

            logger.info(f"Prix collectés pour {collected} cryptos depuis Binance")
            return collected > 0

        except Exception as e:
            logger.error(f"Erreur collecte prix Binance: {e}")
            return False
    
    def collect_crypto_news(self):
        """Collecte les actualités crypto depuis les flux RSS français"""
        news_collected = 0
        
        for source_name, rss_url in [
            ('journalducoin', self.apis['journalducoin']),
            ('cryptoast', self.apis['cryptoast']),
            ('cointribune', self.apis['cointribune'])
        ]:
            try:
                response = requests.get(rss_url, timeout=10)
                if response.status_code == 200:
                    root = ET.fromstring(response.content)
                    
                    for item in root.findall('.//item')[:5]:  # 5 derniers articles
                        try:
                            title = item.find('title').text if item.find('title') is not None else ''
                            description = item.find('description').text if item.find('description') is not None else ''
                            link = item.find('link').text if item.find('link') is not None else ''
                            pub_date = item.find('pubDate').text if item.find('pubDate') is not None else ''
                            
                            # Filtre les actualités crypto
                            if self._is_crypto_related(title, description):
                                news_data = {
                                    'timestamp': datetime.now().isoformat(),
                                    'title': title,
                                    'description': description,
                                    'url': link,
                                    'published_at': pub_date,
                                    'source': source_name,
                                    'tags': self._extract_crypto_tags(title, description)
                                }
                                
                                # Envoie vers Kafka
                                news_id = f"{source_name}_{hash(title)}"
                                self.send_to_kafka(self.topics['news'], news_id, news_data)
                                news_collected += 1
                                
                        except Exception as e:
                            logger.warning(f"Erreur parsing article {source_name}: {e}")
                            continue
                            
            except Exception as e:
                logger.error(f"Erreur collecte news {source_name}: {e}")
                continue
        
        logger.info(f"Actualités collectées: {news_collected}")
        return news_collected > 0
    
    def _is_crypto_related(self, title, description):
        """Vérifie si l'article est lié aux cryptomonnaies"""
        crypto_keywords = [
            'bitcoin', 'btc', 'ethereum', 'eth', 'crypto', 'blockchain',
            'solana', 'cardano', 'polygon', 'defi', 'nft', 'web3',
            'binance', 'coinbase', 'trading', 'altcoin', 'stablecoin'
        ]
        
        content = f"{title.lower()} {description.lower()}"
        return any(keyword in content for keyword in crypto_keywords)
    
    def _extract_crypto_tags(self, title, description):
        """Extrait les tags crypto du contenu"""
        content = f"{title.lower()} {description.lower()}"
        tags = []
        
        tag_mapping = {
            'bitcoin': ['bitcoin', 'btc'],
            'ethereum': ['ethereum', 'eth'],
            'solana': ['solana', 'sol'],
            'defi': ['defi', 'finance décentralisée'],
            'nft': ['nft', 'token non fongible'],
            'regulation': ['réglementation', 'régulation'],
            'france': ['france', 'français']
        }
        
        for tag, keywords in tag_mapping.items():
            if any(keyword in content for keyword in keywords):
                tags.append(tag)
        
        return tags if tags else ['crypto']
    
    def send_to_kafka(self, topic, key, data):
        """Envoie des données vers Kafka"""
        try:
            future = self.producer.send(topic, key=key, value=data)
            future.get(timeout=10)  # Attendre la confirmation
            
        except KafkaError as e:
            logger.error(f"Erreur Kafka: {e}")
        except Exception as e:
            logger.error(f"Erreur envoi: {e}")
    
    def run_continuous_collection(self):
        """Lance la collecte en continu"""
        logger.info("Démarrage de la collecte continue...")
        
        while True:
            try:
                # Collecte des prix toutes les 30 secondes
                self.collect_crypto_prices()
                time.sleep(30)
                
                # Collecte des news toutes les 5 minutes
                self.collect_crypto_news()
                time.sleep(270)  # 4min30 + 30s = 5min
                
            except KeyboardInterrupt:
                logger.info("Arrêt demandé par l'utilisateur")
                break
            except Exception as e:
                logger.error(f"Erreur dans la boucle principale: {e}")
                time.sleep(60)  # Attendre 1 minute avant de reprendre
    
    def close(self):
        """Ferme le producteur Kafka"""
        self.producer.close()

if __name__ == "__main__":
    import os
    
    # Configuration Kafka depuis les variables d'environnement
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092').split(',')
    
    producer = CryptoKafkaProducer(kafka_servers)
    
    try:
        producer.run_continuous_collection()
    finally:
        producer.close()
