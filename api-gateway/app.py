#!/usr/bin/env python3
"""
API Gateway pour l'application Flutter
Expose les données Kafka/Spark via REST API
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
from kafka import KafkaConsumer
import json
import logging
from datetime import datetime, timedelta
import threading
import time
import os

# Configuration du logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Permettre les requêtes cross-origin pour Flutter

class CryptoAPIGateway:
    def __init__(self, kafka_servers=['localhost:9092']):
        self.kafka_servers = kafka_servers
        
        # Cache en mémoire pour les données
        self.cache = {
            'prices': {},
            'news': [],
            'alerts': []
        }
        
        # Topics Kafka
        self.topics = {
            'prices': 'crypto-prices',
            'news': 'crypto-news',
            'processed': 'processed-data'
        }
        
        # Démarrer les consumers Kafka en arrière-plan
        self.start_kafka_consumers()
    
    def start_kafka_consumers(self):
        """Démarre les consumers Kafka en arrière-plan"""
        
        def consume_prices():
            """Consumer pour les prix crypto"""
            try:
                consumer = KafkaConsumer(
                    self.topics['prices'],
                    bootstrap_servers=self.kafka_servers,
                    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                    group_id='api-gateway-prices'
                )
                
                logger.info("Consumer prix démarré")
                
                for message in consumer:
                    data = message.value
                    symbol = data.get('symbol')
                    if symbol:
                        self.cache['prices'][symbol] = data
                        logger.debug(f"Prix mis à jour pour {symbol}")
                        
            except Exception as e:
                logger.error(f"Erreur consumer prix: {e}")
        
        def consume_news():
            """Consumer pour les actualités"""
            try:
                consumer = KafkaConsumer(
                    self.topics['news'],
                    bootstrap_servers=self.kafka_servers,
                    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                    group_id='api-gateway-news'
                )
                
                logger.info("Consumer news démarré")
                
                for message in consumer:
                    data = message.value
                    
                    # Ajouter au cache (garder les 50 dernières)
                    self.cache['news'].insert(0, data)
                    if len(self.cache['news']) > 50:
                        self.cache['news'] = self.cache['news'][:50]
                    
                    logger.debug(f"Nouvelle actualité: {data.get('title', '')[:50]}...")
                    
            except Exception as e:
                logger.error(f"Erreur consumer news: {e}")
        
        # Démarrer les threads
        threading.Thread(target=consume_prices, daemon=True).start()
        threading.Thread(target=consume_news, daemon=True).start()

# Instance globale
gateway = CryptoAPIGateway(
    kafka_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092').split(',')
)

@app.route('/health')
def health():
    """Endpoint de santé"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'cached_prices': len(gateway.cache['prices']),
        'cached_news': len(gateway.cache['news'])
    })

@app.route('/api/crypto/prices')
def get_crypto_prices():
    """Récupère les prix des cryptomonnaies"""
    try:
        limit = request.args.get('limit', 20, type=int)
        
        # Convertir le cache en liste et trier par timestamp
        prices_list = list(gateway.cache['prices'].values())
        prices_list.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        return jsonify({
            'success': True,
            'data': prices_list[:limit],
            'timestamp': datetime.now().isoformat(),
            'source': 'kafka-stream'
        })
        
    except Exception as e:
        logger.error(f"Erreur get_crypto_prices: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/crypto/prices/<symbol>')
def get_crypto_price(symbol):
    """Récupère le prix d'une crypto spécifique"""
    try:
        symbol_lower = symbol.lower()
        
        if symbol_lower in gateway.cache['prices']:
            return jsonify({
                'success': True,
                'data': gateway.cache['prices'][symbol_lower],
                'timestamp': datetime.now().isoformat()
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Prix non trouvé pour {symbol}'
            }), 404
            
    except Exception as e:
        logger.error(f"Erreur get_crypto_price: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/crypto/news')
def get_crypto_news():
    """Récupère les actualités crypto"""
    try:
        limit = request.args.get('limit', 20, type=int)
        category = request.args.get('category', None)
        
        news_list = gateway.cache['news']
        
        # Filtrer par catégorie si spécifiée
        if category:
            news_list = [
                news for news in news_list 
                if category.lower() in [tag.lower() for tag in news.get('tags', [])]
            ]
        
        return jsonify({
            'success': True,
            'data': news_list[:limit],
            'timestamp': datetime.now().isoformat(),
            'source': 'kafka-stream'
        })
        
    except Exception as e:
        logger.error(f"Erreur get_crypto_news: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/crypto/trending')
def get_trending_cryptos():
    """Récupère les cryptos tendance (basé sur le volume et variation)"""
    try:
        # Trier par volume et variation 24h
        prices_list = list(gateway.cache['prices'].values())
        
        # Filtrer et trier par volume et changement
        trending = sorted(
            [p for p in prices_list if p.get('volume_24h_usd', 0) > 0],
            key=lambda x: (
                abs(x.get('change_24h', 0)) * x.get('volume_24h_usd', 0)
            ),
            reverse=True
        )[:10]
        
        return jsonify({
            'success': True,
            'data': trending,
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"Erreur get_trending_cryptos: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/stats')
def get_stats():
    """Statistiques générales du système"""
    try:
        total_market_cap = sum(
            p.get('market_cap_usd', 0) 
            for p in gateway.cache['prices'].values()
        )
        
        total_volume = sum(
            p.get('volume_24h_usd', 0) 
            for p in gateway.cache['prices'].values()
        )
        
        # Calculer les gains/pertes
        gainers = [
            p for p in gateway.cache['prices'].values() 
            if p.get('change_24h', 0) > 0
        ]
        
        losers = [
            p for p in gateway.cache['prices'].values() 
            if p.get('change_24h', 0) < 0
        ]
        
        return jsonify({
            'success': True,
            'data': {
                'total_cryptos': len(gateway.cache['prices']),
                'total_market_cap_usd': total_market_cap,
                'total_volume_24h_usd': total_volume,
                'gainers_count': len(gainers),
                'losers_count': len(losers),
                'news_count': len(gateway.cache['news']),
                'last_update': datetime.now().isoformat()
            }
        })
        
    except Exception as e:
        logger.error(f"Erreur get_stats: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == '__main__':
    logger.info("Démarrage de l'API Gateway...")
    app.run(host='0.0.0.0', port=3000, debug=False)
