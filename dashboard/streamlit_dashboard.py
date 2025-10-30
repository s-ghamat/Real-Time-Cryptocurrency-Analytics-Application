#!/usr/bin/env python3
"""
Dynamic Viewer - Dashboard Streamlit avec visualisations temps réel
"""

import streamlit as st
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import pandas as pd
import duckdb
import time
from datetime import datetime, timedelta
import json
import numpy as np

# Configuration de la page
st.set_page_config(
    page_title="🚀 Crypto Analytics Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

class CryptoDashboard:
    def __init__(self):
        """Initialise le dashboard crypto"""
        self.db_path = "analytics/crypto_analytics.db"
        self.conn = None
        self.connect_db()
    
    def connect_db(self):
        """Connexion à la base DuckDB"""
        try:
            self.conn = duckdb.connect(self.db_path)
        except Exception as e:
            st.error(f"❌ Erreur connexion base de données: {e}")
    
    def get_crypto_list(self):
        """Récupère la liste des cryptos disponibles"""
        try:
            result = self.conn.execute("""
                SELECT DISTINCT symbol 
                FROM crypto_analytics 
                ORDER BY symbol
            """).fetchall()
            return [row[0] for row in result]
        except:
            return []
    
    def get_latest_prices(self):
        """Récupère les derniers prix des cryptos"""
        try:
            df = self.conn.execute("""
                SELECT 
                    symbol,
                    current_price,
                    price_change_24h,
                    price_change_percentage_24h,
                    volume_24h,
                    rsi,
                    trend_signal,
                    momentum_signal,
                    timestamp
                FROM crypto_analytics 
                WHERE timestamp > (CURRENT_TIMESTAMP - INTERVAL 1 HOUR)
                ORDER BY timestamp DESC
            """).df()
            return df
        except Exception as e:
            st.error(f"Erreur récupération prix: {e}")
            return pd.DataFrame()
    
    def get_price_history(self, symbol, hours=24):
        """Récupère l'historique des prix pour un symbole"""
        try:
            df = self.conn.execute("""
                SELECT 
                    timestamp,
                    current_price,
                    sma_20,
                    bollinger_upper,
                    bollinger_lower,
                    rsi,
                    volume_24h
                FROM crypto_analytics 
                WHERE symbol = ? 
                AND timestamp > (CURRENT_TIMESTAMP - INTERVAL {} HOUR)
                ORDER BY timestamp
            """.format(hours), [symbol]).df()
            return df
        except Exception as e:
            st.error(f"Erreur historique {symbol}: {e}")
            return pd.DataFrame()
    
    def get_technical_indicators(self, symbol):
        """Récupère les indicateurs techniques pour un symbole"""
        try:
            result = self.conn.execute("""
                SELECT 
                    sma_5, sma_10, sma_20, sma_50,
                    ema_12, ema_26, macd, macd_signal,
                    rsi, bollinger_upper, bollinger_lower,
                    volatility, trend_signal, momentum_signal
                FROM crypto_analytics 
                WHERE symbol = ? 
                ORDER BY timestamp DESC 
                LIMIT 1
            """, [symbol]).fetchone()
            
            if result:
                return {
                    'sma_5': result[0], 'sma_10': result[1], 'sma_20': result[2], 'sma_50': result[3],
                    'ema_12': result[4], 'ema_26': result[5], 'macd': result[6], 'macd_signal': result[7],
                    'rsi': result[8], 'bollinger_upper': result[9], 'bollinger_lower': result[10],
                    'volatility': result[11], 'trend_signal': result[12], 'momentum_signal': result[13]
                }
            return {}
        except Exception as e:
            st.error(f"Erreur indicateurs {symbol}: {e}")
            return {}
    
    def get_recent_alerts(self, limit=10):
        """Récupère les alertes récentes"""
        try:
            df = self.conn.execute("""
                SELECT 
                    symbol, alert_type, message, severity,
                    current_value, threshold_value, confidence,
                    timestamp, created_at
                FROM advanced_alerts 
                ORDER BY created_at DESC 
                LIMIT ?
            """, [limit]).df()
            return df
        except Exception as e:
            st.error(f"Erreur alertes: {e}")
            return pd.DataFrame()
    
    def get_news_sentiment(self, limit=20):
        """Récupère l'analyse de sentiment des news"""
        try:
            df = self.conn.execute("""
                SELECT 
                    title, sentiment_polarity, sentiment_label,
                    mentioned_cryptos, published_at, source
                FROM news_sentiment 
                ORDER BY published_at DESC 
                LIMIT ?
            """, [limit]).df()
            return df
        except Exception as e:
            st.error(f"Erreur sentiment news: {e}")
            return pd.DataFrame()
    
    def get_performance_metrics(self):
        """Récupère les métriques de performance"""
        try:
            result = self.conn.execute("""
                SELECT 
                    total_cryptos_tracked,
                    total_news_processed,
                    avg_sentiment_score,
                    market_volatility,
                    processing_latency_ms
                FROM performance_metrics 
                ORDER BY timestamp DESC 
                LIMIT 1
            """).fetchone()
            
            if result:
                return {
                    'cryptos_tracked': result[0],
                    'news_processed': result[1],
                    'avg_sentiment': result[2],
                    'market_volatility': result[3],
                    'processing_latency': result[4]
                }
            return {}
        except:
            return {}

def main():
    """Fonction principale du dashboard"""
    
    # Titre principal
    st.title("🚀 Crypto Analytics Dashboard")
    st.markdown("**Dashboard temps réel pour l'analyse des cryptomonnaies**")
    
    # Initialiser le dashboard
    dashboard = CryptoDashboard()
    
    # Sidebar pour les contrôles
    st.sidebar.header("⚙️ Contrôles")
    
    # Auto-refresh
    auto_refresh = st.sidebar.checkbox("🔄 Auto-refresh (30s)", value=True)
    if auto_refresh:
        time.sleep(1)
        st.rerun()
    
    # Sélection de crypto
    crypto_list = dashboard.get_crypto_list()
    if crypto_list:
        selected_crypto = st.sidebar.selectbox("📈 Sélectionner une crypto", crypto_list)
    else:
        st.warning("⚠️ Aucune donnée crypto disponible")
        return
    
    # Période d'historique
    time_period = st.sidebar.selectbox(
        "⏱️ Période d'historique",
        ["1h", "6h", "24h", "7d"],
        index=2
    )
    
    hours_map = {"1h": 1, "6h": 6, "24h": 24, "7d": 168}
    hours = hours_map[time_period]
    
    # Métriques de performance en haut
    st.header("📊 Métriques Système")
    perf_metrics = dashboard.get_performance_metrics()
    
    if perf_metrics:
        col1, col2, col3, col4, col5 = st.columns(5)
        
        with col1:
            st.metric("🪙 Cryptos Trackées", perf_metrics.get('cryptos_tracked', 0))
        
        with col2:
            st.metric("📰 News Traitées", perf_metrics.get('news_processed', 0))
        
        with col3:
            sentiment_val = perf_metrics.get('avg_sentiment', 0)
            sentiment_label = "😊" if sentiment_val > 0.1 else "😐" if sentiment_val > -0.1 else "😞"
            st.metric(f"{sentiment_label} Sentiment Moyen", f"{sentiment_val:.3f}")
        
        with col4:
            volatility = perf_metrics.get('market_volatility', 0)
            st.metric("📈 Volatilité Marché", f"{volatility:.4f}")
        
        with col5:
            latency = perf_metrics.get('processing_latency', 0)
            st.metric("⚡ Latence (ms)", f"{latency:.1f}")
    
    # Layout principal en colonnes
    col_left, col_right = st.columns([2, 1])
    
    with col_left:
        # Graphique principal des prix
        st.header(f"📈 {selected_crypto.upper()} - Analyse Technique")
        
        price_history = dashboard.get_price_history(selected_crypto, hours)
        
        if not price_history.empty:
            # Créer le graphique avec Plotly
            fig = make_subplots(
                rows=3, cols=1,
                subplot_titles=(f'{selected_crypto.upper()} Prix & Bandes de Bollinger', 'RSI', 'Volume'),
                vertical_spacing=0.08,
                row_heights=[0.6, 0.2, 0.2]
            )
            
            # Prix et Bandes de Bollinger
            fig.add_trace(
                go.Scatter(
                    x=price_history['timestamp'],
                    y=price_history['current_price'],
                    name='Prix',
                    line=dict(color='#00D4AA', width=2)
                ),
                row=1, col=1
            )
            
            if 'sma_20' in price_history.columns and not price_history['sma_20'].isna().all():
                fig.add_trace(
                    go.Scatter(
                        x=price_history['timestamp'],
                        y=price_history['sma_20'],
                        name='SMA 20',
                        line=dict(color='orange', width=1)
                    ),
                    row=1, col=1
                )
            
            if 'bollinger_upper' in price_history.columns and not price_history['bollinger_upper'].isna().all():
                fig.add_trace(
                    go.Scatter(
                        x=price_history['timestamp'],
                        y=price_history['bollinger_upper'],
                        name='Bollinger Sup',
                        line=dict(color='red', width=1, dash='dash')
                    ),
                    row=1, col=1
                )
                
                fig.add_trace(
                    go.Scatter(
                        x=price_history['timestamp'],
                        y=price_history['bollinger_lower'],
                        name='Bollinger Inf',
                        line=dict(color='red', width=1, dash='dash'),
                        fill='tonexty',
                        fillcolor='rgba(255,0,0,0.1)'
                    ),
                    row=1, col=1
                )
            
            # RSI
            if 'rsi' in price_history.columns and not price_history['rsi'].isna().all():
                fig.add_trace(
                    go.Scatter(
                        x=price_history['timestamp'],
                        y=price_history['rsi'],
                        name='RSI',
                        line=dict(color='purple', width=2)
                    ),
                    row=2, col=1
                )
                
                # Lignes RSI 30 et 70
                fig.add_hline(y=70, line_dash="dash", line_color="red", row=2, col=1)
                fig.add_hline(y=30, line_dash="dash", line_color="green", row=2, col=1)
            
            # Volume
            if 'volume_24h' in price_history.columns and not price_history['volume_24h'].isna().all():
                fig.add_trace(
                    go.Bar(
                        x=price_history['timestamp'],
                        y=price_history['volume_24h'],
                        name='Volume 24h',
                        marker_color='lightblue'
                    ),
                    row=3, col=1
                )
            
            fig.update_layout(
                height=800,
                showlegend=True,
                title_text=f"Analyse Technique - {selected_crypto.upper()}",
                template="plotly_dark"
            )
            
            st.plotly_chart(fig, use_container_width=True)
        
        else:
            st.warning(f"⚠️ Pas de données historiques pour {selected_crypto}")
    
    with col_right:
        # Indicateurs techniques actuels
        st.header("🔢 Indicateurs Techniques")
        
        indicators = dashboard.get_technical_indicators(selected_crypto)
        
        if indicators:
            # RSI avec couleur
            rsi = indicators.get('rsi')
            if rsi:
                if rsi > 70:
                    rsi_color = "🔴"
                elif rsi < 30:
                    rsi_color = "🟢"
                else:
                    rsi_color = "🟡"
                st.metric(f"{rsi_color} RSI", f"{rsi:.2f}")
            
            # MACD
            macd = indicators.get('macd')
            macd_signal = indicators.get('macd_signal')
            if macd and macd_signal:
                macd_diff = macd - macd_signal
                macd_color = "🟢" if macd_diff > 0 else "🔴"
                st.metric(f"{macd_color} MACD", f"{macd:.6f}")
            
            # Volatilité
            volatility = indicators.get('volatility')
            if volatility:
                st.metric("📊 Volatilité", f"{volatility:.4f}")
            
            # Signaux
            trend_signal = indicators.get('trend_signal', 'N/A')
            momentum_signal = indicators.get('momentum_signal', 'N/A')
            
            st.markdown("### 🎯 Signaux Trading")
            st.markdown(f"**Tendance:** {trend_signal}")
            st.markdown(f"**Momentum:** {momentum_signal}")
        
        # Alertes récentes
        st.header("🚨 Alertes Récentes")
        
        alerts_df = dashboard.get_recent_alerts(5)
        
        if not alerts_df.empty:
            for _, alert in alerts_df.iterrows():
                severity_icon = {
                    'LOW': '🟡',
                    'MEDIUM': '🟠',
                    'HIGH': '🔴',
                    'CRITICAL': '🚨'
                }.get(alert['severity'], '⚪')
                
                with st.expander(f"{severity_icon} {alert['symbol']} - {alert['alert_type']}"):
                    st.write(alert['message'])
                    st.write(f"**Confiance:** {alert['confidence']:.0%}")
                    st.write(f"**Timestamp:** {alert['timestamp']}")
        else:
            st.info("Aucune alerte récente")
    
    # Section News et Sentiment
    st.header("📰 Analyse de Sentiment des News")
    
    news_df = dashboard.get_news_sentiment(10)
    
    if not news_df.empty:
        col_news1, col_news2 = st.columns([2, 1])
        
        with col_news1:
            # Liste des news avec sentiment
            for _, news in news_df.iterrows():
                sentiment_icon = {
                    'POSITIVE': '😊',
                    'NEGATIVE': '😞',
                    'NEUTRAL': '😐'
                }.get(news['sentiment_label'], '❓')
                
                with st.expander(f"{sentiment_icon} {news['title'][:60]}..."):
                    st.write(f"**Sentiment:** {news['sentiment_label']} ({news['sentiment_polarity']:.3f})")
                    st.write(f"**Source:** {news['source']}")
                    st.write(f"**Cryptos mentionnées:** {news['mentioned_cryptos']}")
                    st.write(f"**Publié:** {news['published_at']}")
        
        with col_news2:
            # Graphique de distribution du sentiment
            sentiment_counts = news_df['sentiment_label'].value_counts()
            
            fig_sentiment = px.pie(
                values=sentiment_counts.values,
                names=sentiment_counts.index,
                title="Distribution du Sentiment",
                color_discrete_map={
                    'POSITIVE': '#00D4AA',
                    'NEGATIVE': '#FF6B6B',
                    'NEUTRAL': '#FFE66D'
                }
            )
            
            fig_sentiment.update_layout(template="plotly_dark")
            st.plotly_chart(fig_sentiment, use_container_width=True)
    
    else:
        st.info("Aucune news disponible")
    
    # Footer avec timestamp
    st.markdown("---")
    st.markdown(f"**Dernière mise à jour:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
