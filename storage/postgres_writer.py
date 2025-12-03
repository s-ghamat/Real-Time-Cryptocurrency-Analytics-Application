#!/usr/bin/env python3
"""
PostgreSQL Writer pour Grafana
Écrit les données crypto dans PostgreSQL pour la visualisation Grafana
"""

try:
    import psycopg
    PSYCOPG3 = True
except ImportError:
    import psycopg2
    from psycopg2.extras import execute_values
    PSYCOPG3 = False

from datetime import datetime
import logging
import sys
import io

logger = logging.getLogger(__name__)

# Patcher sys.stderr pour gérer les erreurs d'encodage PostgreSQL
_original_stderr = sys.stderr

class SafeStderr:
    """Wrapper pour stderr qui gère les erreurs d'encodage"""
    def __init__(self):
        self.buffer = io.BytesIO()
        self.text_wrapper = io.TextIOWrapper(self.buffer, encoding='utf-8', errors='replace')
    
    def write(self, s):
        try:
            if isinstance(s, bytes):
                self.text_wrapper.buffer.write(s)
            else:
                self.text_wrapper.write(str(s))
        except:
            pass
    
    def flush(self):
        try:
            self.text_wrapper.flush()
        except:
            pass
    
    def __getattr__(self, name):
        return getattr(_original_stderr, name)

class PostgreSQLWriter:
    """Writer pour écrire les données dans PostgreSQL pour Grafana"""
    
    def __init__(self, host='localhost', port=5432, database='crypto', 
                 user='admin', password='admin'):
        """Initialise la connexion PostgreSQL"""
        self.host = host
        self.port = port
        self.database = database
        self.user = user
        self.password = password
        self.conn = None
        self._connect()
        self._create_tables()
    
    def _connect(self):
        """Établit la connexion PostgreSQL"""
        try:
            if PSYCOPG3:
                # Utiliser psycopg3 qui gère mieux les erreurs d'encodage
                self.conn = psycopg.connect(
                    host=str(self.host),
                    port=int(self.port),
                    dbname=str(self.database),
                    user=str(self.user),
                    password=str(self.password),
                    connect_timeout=5
                )
                self.conn.autocommit = True
                logger.info("✅ Connexion PostgreSQL établie (psycopg3)")
            else:
                # Utiliser psycopg2 avec gestion d'erreur pour l'encodage
                import sys
                import io
                
                # Rediriger stderr pour éviter les problèmes d'encodage
                old_stderr = sys.stderr
                sys.stderr = io.TextIOWrapper(io.BytesIO(), encoding='utf-8', errors='replace')
                
                try:
                    self.conn = psycopg2.connect(
                        host=str(self.host),
                        port=int(self.port),
                        database=str(self.database),
                        user=str(self.user),
                        password=str(self.password),
                        connect_timeout=5
                    )
                    self.conn.autocommit = True
                    with self.conn.cursor() as cur:
                        cur.execute("SET client_encoding TO 'UTF8'")
                    logger.info("✅ Connexion PostgreSQL établie (psycopg2)")
                except (UnicodeDecodeError, psycopg2.OperationalError) as e:
                    # Erreur d'encodage ou opérationnelle - réessayer sans redirection stderr
                    sys.stderr = old_stderr
                    try:
                        dsn = f"host={self.host} port={self.port} dbname={self.database} user={self.user} password={self.password}"
                        self.conn = psycopg2.connect(dsn, connect_timeout=5)
                        self.conn.autocommit = True
                        logger.info("✅ Connexion PostgreSQL établie (après gestion erreur encodage)")
                    except Exception as e2:
                        logger.error(f"❌ Impossible de se connecter à PostgreSQL sur {self.host}:{self.port}")
                        logger.error(f"   Vérifiez que l'utilisateur '{self.user}' existe et que le port est correct")
                        raise
                finally:
                    sys.stderr = old_stderr
        except Exception as e:
            error_msg = f"{type(e).__name__}: {str(e)[:200]}"
            logger.error(f"❌ Erreur connexion PostgreSQL: {error_msg}")
            raise
    
    def _create_tables(self):
        """Crée les tables si elles n'existent pas"""
        try:
            with self.conn.cursor() as cur:
                # Table pour les prix crypto
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS crypto_prices_grafana (
                        time TIMESTAMP NOT NULL,
                        symbol TEXT NOT NULL,
                        price DOUBLE PRECISION NOT NULL,
                        volume_24h BIGINT,
                        market_cap BIGINT,
                        price_change_24h DOUBLE PRECISION,
                        PRIMARY KEY (time, symbol)
                    )
                """)
                
                # Table pour les indicateurs techniques
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS technical_indicators_grafana (
                        time TIMESTAMP NOT NULL,
                        symbol TEXT NOT NULL,
                        rsi DOUBLE PRECISION,
                        macd DOUBLE PRECISION,
                        macd_signal DOUBLE PRECISION,
                        sma_20 DOUBLE PRECISION,
                        ema_12 DOUBLE PRECISION,
                        ema_26 DOUBLE PRECISION,
                        bb_upper DOUBLE PRECISION,
                        bb_lower DOUBLE PRECISION,
                        PRIMARY KEY (time, symbol)
                    )
                """)
                
                # Table pour le sentiment analysis
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS crypto_sentiment_grafana (
                        time TIMESTAMP NOT NULL,
                        source TEXT,
                        sentiment TEXT,
                        score DOUBLE PRECISION,
                        title TEXT,
                        PRIMARY KEY (time, source, title)
                    )
                """)
                
                # Créer les index pour performance
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_crypto_prices_time 
                    ON crypto_prices_grafana(time DESC)
                """)
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_crypto_prices_symbol 
                    ON crypto_prices_grafana(symbol)
                """)
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_indicators_time 
                    ON technical_indicators_grafana(time DESC)
                """)
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_indicators_symbol 
                    ON technical_indicators_grafana(symbol)
                """)
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_sentiment_time 
                    ON crypto_sentiment_grafana(time DESC)
                """)
                
            logger.info("✅ Tables PostgreSQL créées/vérifiées")
        except Exception as e:
            logger.error(f"❌ Erreur création tables PostgreSQL: {e}")
            raise
    
    def write_price(self, symbol, price, volume_24h=None, market_cap=None, 
                    price_change_24h=None, timestamp=None):
        """Écrit un prix crypto dans PostgreSQL"""
        if timestamp is None:
            timestamp = datetime.now()
        
        try:
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO crypto_prices_grafana 
                    (time, symbol, price, volume_24h, market_cap, price_change_24h)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (time, symbol) DO UPDATE SET
                        price = EXCLUDED.price,
                        volume_24h = EXCLUDED.volume_24h,
                        market_cap = EXCLUDED.market_cap,
                        price_change_24h = EXCLUDED.price_change_24h
                """, (timestamp, symbol.upper(), price, volume_24h, market_cap, price_change_24h))
        except Exception as e:
            logger.error(f"❌ Erreur écriture prix PostgreSQL {symbol}: {e}")
    
    def write_indicators(self, symbol, indicators, timestamp=None):
        """Écrit les indicateurs techniques dans PostgreSQL"""
        if timestamp is None:
            timestamp = datetime.now()
        
        try:
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO technical_indicators_grafana 
                    (time, symbol, rsi, macd, macd_signal, sma_20, ema_12, ema_26, bb_upper, bb_lower)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (time, symbol) DO UPDATE SET
                        rsi = EXCLUDED.rsi,
                        macd = EXCLUDED.macd,
                        macd_signal = EXCLUDED.macd_signal,
                        sma_20 = EXCLUDED.sma_20,
                        ema_12 = EXCLUDED.ema_12,
                        ema_26 = EXCLUDED.ema_26,
                        bb_upper = EXCLUDED.bb_upper,
                        bb_lower = EXCLUDED.bb_lower
                """, (
                    timestamp, symbol.upper(),
                    indicators.get('rsi'),
                    indicators.get('macd'),
                    indicators.get('macd_signal'),
                    indicators.get('sma_20'),
                    indicators.get('ema_12'),
                    indicators.get('ema_26'),
                    indicators.get('bollinger_upper'),
                    indicators.get('bollinger_lower')
                ))
        except Exception as e:
            logger.error(f"❌ Erreur écriture indicateurs PostgreSQL {symbol}: {e}")
    
    def write_sentiment(self, source, sentiment, score, title=None, timestamp=None):
        """Écrit le sentiment analysis dans PostgreSQL"""
        if timestamp is None:
            timestamp = datetime.now()
        
        try:
            with self.conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO crypto_sentiment_grafana 
                    (time, source, sentiment, score, title)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (time, source, title) DO UPDATE SET
                        sentiment = EXCLUDED.sentiment,
                        score = EXCLUDED.score
                """, (timestamp, source, sentiment, score, title or ''))
        except Exception as e:
            logger.error(f"❌ Erreur écriture sentiment PostgreSQL: {e}")
    
    def close(self):
        """Ferme la connexion PostgreSQL"""
        if self.conn:
            self.conn.close()
            logger.info("✅ Connexion PostgreSQL fermée")


