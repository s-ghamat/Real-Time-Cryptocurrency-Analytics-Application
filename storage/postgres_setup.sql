-- PostgreSQL Setup pour Grafana
-- Ce script crée les tables nécessaires pour la visualisation Grafana

-- Table pour les prix crypto (Grafana-ready avec colonne 'time')
CREATE TABLE IF NOT EXISTS crypto_prices_grafana (
    time TIMESTAMP NOT NULL,
    symbol TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL,
    volume_24h BIGINT,
    market_cap BIGINT,
    price_change_24h DOUBLE PRECISION,
    PRIMARY KEY (time, symbol)
);

-- Table pour les indicateurs techniques (Grafana-ready)
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
);

-- Table pour le sentiment analysis (Grafana-ready)
CREATE TABLE IF NOT EXISTS crypto_sentiment_grafana (
    time TIMESTAMP NOT NULL,
    source TEXT,
    sentiment TEXT,
    score DOUBLE PRECISION,
    title TEXT,
    PRIMARY KEY (time, source, title)
);

-- Index pour améliorer les performances des requêtes Grafana
CREATE INDEX IF NOT EXISTS idx_crypto_prices_time ON crypto_prices_grafana(time DESC);
CREATE INDEX IF NOT EXISTS idx_crypto_prices_symbol ON crypto_prices_grafana(symbol);
CREATE INDEX IF NOT EXISTS idx_indicators_time ON technical_indicators_grafana(time DESC);
CREATE INDEX IF NOT EXISTS idx_indicators_symbol ON technical_indicators_grafana(symbol);
CREATE INDEX IF NOT EXISTS idx_sentiment_time ON crypto_sentiment_grafana(time DESC);

-- Commentaires pour documentation
COMMENT ON TABLE crypto_prices_grafana IS 'Prix des cryptomonnaies pour visualisation Grafana';
COMMENT ON TABLE technical_indicators_grafana IS 'Indicateurs techniques calculés pour Grafana';
COMMENT ON TABLE crypto_sentiment_grafana IS 'Analyse de sentiment des actualités crypto pour Grafana';


