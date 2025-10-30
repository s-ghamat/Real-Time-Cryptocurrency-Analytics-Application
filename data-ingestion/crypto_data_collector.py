#!/usr/bin/env python3
"""
Collecteur de données crypto en temps réel
Collecte les prix des cryptomonnaies depuis plusieurs APIs
"""

import requests
import pandas as pd
import json
import time
from datetime import datetime
import websocket
import threading

class CryptoDataCollector:
    def __init__(self):
        self.base_urls = {
            'coinapi': 'https://rest.coinapi.io/v1/',
            'binance': 'https://api.binance.com/api/v3/',
            'coinbase': 'https://api.coinbase.com/v2/'
        }
        self.symbols = ['BTC', 'ETH', 'ADA', 'SOL', 'DOT']
        
    def get_crypto_prices(self):
        """Récupère les prix actuels des cryptomonnaies"""
        prices = []
        timestamp = datetime.now()
        
        for symbol in self.symbols:
            try:
                # Binance API (gratuite)
                url = f"{self.base_urls['binance']}ticker/price?symbol={symbol}USDT"
                response = requests.get(url, timeout=5)
                
                if response.status_code == 200:
                    data = response.json()
                    prices.append({
                        'timestamp': timestamp,
                        'symbol': symbol,
                        'price': float(data['price']),
                        'source': 'binance'
                    })
            except Exception as e:
                print(f"Erreur pour {symbol}: {e}")
                
        return pd.DataFrame(prices)
    
    def stream_data(self, callback=None):
        """Stream de données en temps réel"""
        while True:
            df = self.get_crypto_prices()
            if not df.empty:
                print(f"Collecté {len(df)} prix à {datetime.now()}")
                if callback:
                    callback(df)
            time.sleep(10)  # Collecte toutes les 10 secondes

if __name__ == "__main__":
    collector = CryptoDataCollector()
    
    def save_to_csv(df):
        df.to_csv('crypto_prices.csv', mode='a', header=False, index=False)
    
    collector.stream_data(callback=save_to_csv)
