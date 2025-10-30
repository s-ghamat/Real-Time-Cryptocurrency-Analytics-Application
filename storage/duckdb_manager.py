#!/usr/bin/env python3
"""
Gestionnaire DuckDB pour le stockage des données crypto
Inspiré du bootstrap fourni dans le projet
"""

import duckdb
import pandas as pd
from pathlib import Path

class CryptoDuckDBManager:
    def __init__(self, db_path="crypto_database.db"):
        self.db_path = db_path
        self.connection = None
        
    def connect(self):
        """Connexion à la base DuckDB"""
        self.connection = duckdb.connect(self.db_path)
        self._create_tables()
        
    def _create_tables(self):
        """Création des tables pour les données crypto"""
        self.connection.sql("""
            CREATE TABLE IF NOT EXISTS crypto_prices (
                timestamp TIMESTAMP,
                symbol VARCHAR,
                price DOUBLE,
                source VARCHAR,
                volume DOUBLE DEFAULT NULL,
                market_cap DOUBLE DEFAULT NULL
            )
        """)
        
    def import_csv_data(self, csv_path):
        """Import des données CSV vers DuckDB"""
        self.connection.sql(f"""
            INSERT INTO crypto_prices 
            SELECT * FROM read_csv('{csv_path}', 
                types={{"symbol": "VARCHAR", "source": "VARCHAR"}})
        """)
        
    def export_to_parquet(self, output_path="crypto_data.parquet"):
        """Export vers format Parquet pour optimisation"""
        self.connection.sql(f"""
            COPY crypto_prices TO '{output_path}' (FORMAT PARQUET)
        """)
        
    def get_latest_prices(self, limit=100):
        """Récupération des derniers prix"""
        return self.connection.sql(f"""
            SELECT * FROM crypto_prices 
            ORDER BY timestamp DESC 
            LIMIT {limit}
        """).df()
        
    def get_price_history(self, symbol, hours=24):
        """Historique des prix pour un symbole"""
        return self.connection.sql(f"""
            SELECT timestamp, price 
            FROM crypto_prices 
            WHERE symbol = '{symbol}' 
            AND timestamp >= NOW() - INTERVAL '{hours} HOURS'
            ORDER BY timestamp
        """).df()
        
    def close(self):
        """Fermeture de la connexion"""
        if self.connection:
            self.connection.close()

if __name__ == "__main__":
    # Test du gestionnaire DuckDB
    db = CryptoDuckDBManager()
    db.connect()
    
    # Exemple d'utilisation
    print("Tables créées avec succès")
    print("Derniers prix:", db.get_latest_prices(5))
    
    db.close()
