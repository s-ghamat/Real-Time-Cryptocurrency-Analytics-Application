#!/usr/bin/env python3
"""
Producteur Kafka pour données crypto
Collecte et envoie les données vers Kafka
"""

import os
import json
import time
import requests
import logging
from datetime import datetime
from kafka import KafkaProducer
from kafka.errors import KafkaError
import xml.etree.ElementTree as ET
import certifi

# Corriger le problème SSL au démarrage (avant toute requête HTTP)
# PostgreSQL définit un mauvais chemin SSL_CERT_FILE, on le remplace
os.environ['SSL_CERT_FILE'] = certifi.where()
os.environ['REQUESTS_CA_BUNDLE'] = certifi.where()

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CryptoKafkaProducer:
    def __init__(self, kafka_servers=['localhost:9092'], coingecko_api_key=None):
        """Initialise le producteur Kafka"""
        self.producer = KafkaProducer(
            bootstrap_servers=kafka_servers,
            value_serializer=lambda x: json.dumps(x).encode('utf-8'),
            key_serializer=lambda x: x.encode('utf-8') if x else None
        )
        
        # Clé API CoinGecko (optionnelle)
        self.coingecko_api_key = coingecko_api_key or os.getenv('COINGECKO_API_KEY')
        
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

            # Récupérer les market caps depuis CoinGecko (une seule requête)
            market_caps = self._fetch_market_caps_from_coingecko()

            for crypto_name, pair in binance_pairs.items():
                try:
                    # Binance price ticker (temps réel, sans limite)
                    price_url = f"{self.apis['binance']}/ticker/24hr?symbol={pair}"
                    response = requests.get(price_url, timeout=5, verify=certifi.where())

                    if response.status_code == 200:
                        data = response.json()
                        price_usd = float(data.get('lastPrice', 0))

                        # Récupérer les données enrichies de CoinGecko si disponibles
                        cg_data = market_caps.get(crypto_name, {})

                        price_data = {
                            'timestamp': timestamp,
                            'symbol': crypto_name,
                            'price_usd': price_usd,
                            'price_eur': cg_data.get('eur', price_usd * 0.92),  # CoinGecko ou approximation
                            'market_cap_usd': cg_data.get('market_cap', 0),  # Depuis CoinGecko
                            'volume_24h_usd': float(data.get('volume', 0)) * price_usd,
                            'change_24h': float(data.get('priceChangePercent', 0)),
                            'source': 'binance+coingecko'
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
                response = requests.get(rss_url, timeout=10, verify=certifi.where())
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

    def _fetch_market_caps_from_coingecko(self):
        """Récupère les market caps et prix EUR depuis CoinGecko (une requête groupée)"""
        try:
            url = f"{self.apis['coingecko']}/simple/price"
            params = {
                'ids': ','.join(self.crypto_symbols),
                'vs_currencies': 'usd,eur',
                'include_market_cap': 'true',
                'include_24hr_vol': 'true'
            }

            headers = {}
            if self.coingecko_api_key:
                headers['x-cg-demo-api-key'] = self.coingecko_api_key

            response = requests.get(url, params=params, headers=headers, timeout=10, verify=certifi.where())

            if response.status_code == 200:
                data = response.json()
                result = {}
                for crypto, info in data.items():
                    result[crypto] = {
                        'eur': info.get('eur', 0),
                        'market_cap': info.get('usd_market_cap', 0)
                    }
                logger.debug(f"CoinGecko: données enrichies récupérées pour {len(result)} cryptos")
                return result
            else:
                logger.warning(f"CoinGecko API: status {response.status_code}")
                return {}

        except Exception as e:
            logger.warning(f"Impossible de récupérer les données CoinGecko: {e}")
            return {}

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
    # Configuration Kafka depuis les variables d'environnement
    kafka_servers = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092').split(',')
    coingecko_api_key = os.getenv('COINGECKO_API_KEY', None)
    
    if coingecko_api_key:
        logger.info("✅ Clé API CoinGecko détectée")
    else:
        logger.info("ℹ️  Aucune clé API CoinGecko - utilisation du plan gratuit (50 req/min)")
        logger.info("   Pour plus de limites, créez une clé sur https://www.coingecko.com/en/api/pricing")
    
    producer = CryptoKafkaProducer(kafka_servers, coingecko_api_key=coingecko_api_key)
    
    try:
        producer.run_continuous_collection()
    finally:
        producer.close()
