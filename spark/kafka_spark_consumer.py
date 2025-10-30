#!/usr/bin/env python3
"""
Job Spark pour consommer les données Kafka et calculer les indicateurs techniques
Intégration complète Kafka → Spark → DuckDB pour le projet T-DAT-901
"""

import os
import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window
import duckdb
import json

class KafkaSparkProcessor:
    def __init__(self):
        # Configuration Spark avec Kafka - version compatible Scala 2.12
        self.spark = SparkSession.builder \
            .appName("CryptoKafkaProcessor") \
            .config("spark.jars.packages", "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0") \
            .config("spark.sql.adaptive.enabled", "true") \
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
            .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
            .master("local[*]") \
            .getOrCreate()
        
        self.spark.sparkContext.setLogLevel("WARN")
        
        # Configuration Kafka
        self.kafka_bootstrap_servers = "localhost:9092"
        self.kafka_topics = ["crypto-prices", "crypto-news"]
        
        # Schéma pour les données crypto
        self.crypto_price_schema = StructType([
            StructField("id", StringType(), True),
            StructField("symbol", StringType(), True),
            StructField("name", StringType(), True),
            StructField("current_price", DoubleType(), True),
            StructField("market_cap", DoubleType(), True),
            StructField("total_volume", DoubleType(), True),
            StructField("price_change_24h", DoubleType(), True),
            StructField("price_change_percentage_24h", DoubleType(), True),
            StructField("timestamp", TimestampType(), True)
        ])
        
        # Initialiser DuckDB
        self.duckdb_conn = duckdb.connect("crypto_analytics.db")
        self._setup_duckdb_tables()
    
    def _setup_duckdb_tables(self):
        """Création des tables DuckDB pour stocker les résultats"""
        self.duckdb_conn.execute("""
            CREATE TABLE IF NOT EXISTS crypto_prices (
                timestamp TIMESTAMP,
                symbol VARCHAR,
                name VARCHAR,
                current_price DOUBLE,
                market_cap DOUBLE,
                total_volume DOUBLE,
                price_change_24h DOUBLE,
                price_change_percentage_24h DOUBLE
            )
        """)
        
        self.duckdb_conn.execute("""
            CREATE TABLE IF NOT EXISTS technical_indicators (
                timestamp TIMESTAMP,
                symbol VARCHAR,
                price DOUBLE,
                sma_5 DOUBLE,
                sma_20 DOUBLE,
                rsi DOUBLE,
                volatility DOUBLE,
                trend_signal VARCHAR
            )
        """)
        
        self.duckdb_conn.execute("""
            CREATE TABLE IF NOT EXISTS crypto_alerts (
                timestamp TIMESTAMP,
                symbol VARCHAR,
                alert_type VARCHAR,
                message VARCHAR,
                price DOUBLE,
                threshold DOUBLE
            )
        """)
    
    def read_kafka_stream(self, topic):
        """Lecture des données depuis Kafka en streaming"""
        return self.spark \
            .readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", self.kafka_bootstrap_servers) \
            .option("subscribe", topic) \
            .option("startingOffsets", "latest") \
            .load()
    
    def parse_crypto_data(self, kafka_df):
        """Parse les données JSON depuis Kafka"""
        return kafka_df.select(
            from_json(col("value").cast("string"), self.crypto_price_schema).alias("data"),
            col("timestamp").alias("kafka_timestamp")
        ).select("data.*", "kafka_timestamp")
    
    def calculate_technical_indicators(self, df):
        """Calcul des indicateurs techniques avec Spark"""
        # Fenêtre pour les calculs par symbole
        window_spec = Window.partitionBy("symbol").orderBy("timestamp")
        window_5 = Window.partitionBy("symbol").orderBy("timestamp").rowsBetween(-4, 0)
        window_20 = Window.partitionBy("symbol").orderBy("timestamp").rowsBetween(-19, 0)
        
        # Calcul des moyennes mobiles
        df_with_sma = df.withColumn(
            "sma_5", avg("current_price").over(window_5)
        ).withColumn(
            "sma_20", avg("current_price").over(window_20)
        )
        
        # Calcul de la volatilité (écart-type sur 20 périodes)
        df_with_volatility = df_with_sma.withColumn(
            "volatility", stddev("current_price").over(window_20)
        )
        
        # Signal de tendance basé sur les moyennes mobiles
        df_with_trend = df_with_volatility.withColumn(
            "trend_signal",
            when(col("sma_5") > col("sma_20"), "BULLISH")
            .when(col("sma_5") < col("sma_20"), "BEARISH")
            .otherwise("NEUTRAL")
        )
        
        # Calcul RSI simplifié (approximation)
        df_with_rsi = df_with_trend.withColumn(
            "price_change", col("current_price") - lag("current_price").over(window_spec)
        ).withColumn(
            "gain", when(col("price_change") > 0, col("price_change")).otherwise(0)
        ).withColumn(
            "loss", when(col("price_change") < 0, -col("price_change")).otherwise(0)
        ).withColumn(
            "avg_gain", avg("gain").over(window_20)
        ).withColumn(
            "avg_loss", avg("loss").over(window_20)
        ).withColumn(
            "rs", col("avg_gain") / col("avg_loss")
        ).withColumn(
            "rsi", 100 - (100 / (1 + col("rs")))
        )
        
        return df_with_rsi.select(
            "timestamp", "symbol", "current_price", "sma_5", "sma_20", 
            "rsi", "volatility", "trend_signal"
        )
    
    def detect_alerts(self, df):
        """Détection d'alertes basées sur les indicateurs"""
        alerts_df = df.filter(
            (col("rsi") > 70) | (col("rsi") < 30) | 
            (col("price_change_percentage_24h") > 10) | 
            (col("price_change_percentage_24h") < -10)
        ).select(
            current_timestamp().alias("timestamp"),
            col("symbol"),
            when(col("rsi") > 70, "RSI_OVERBOUGHT")
            .when(col("rsi") < 30, "RSI_OVERSOLD")
            .when(col("price_change_percentage_24h") > 10, "PRICE_SURGE")
            .when(col("price_change_percentage_24h") < -10, "PRICE_DROP")
            .alias("alert_type"),
            concat(
                lit("Alert for "), col("symbol"), lit(": "),
                when(col("rsi") > 70, "RSI indicates overbought condition")
                .when(col("rsi") < 30, "RSI indicates oversold condition")
                .when(col("price_change_percentage_24h") > 10, "Price surge detected")
                .when(col("price_change_percentage_24h") < -10, "Price drop detected")
            ).alias("message"),
            col("current_price").alias("price"),
            when(col("rsi") > 70, 70.0)
            .when(col("rsi") < 30, 30.0)
            .when(col("price_change_percentage_24h") > 10, 10.0)
            .when(col("price_change_percentage_24h") < -10, -10.0)
            .alias("threshold")
        )
        
        return alerts_df
    
    def save_to_duckdb(self, df, table_name):
        """Sauvegarde des données dans DuckDB"""
        def save_batch(batch_df, batch_id):
            # Convertir en Pandas puis insérer dans DuckDB
            pandas_df = batch_df.toPandas()
            if not pandas_df.empty:
                self.duckdb_conn.register("temp_df", pandas_df)
                self.duckdb_conn.execute(f"INSERT INTO {table_name} SELECT * FROM temp_df")
                print(f"Batch {batch_id}: Inserted {len(pandas_df)} rows into {table_name}")
        
        return save_batch
    
    def start_processing(self):
        """Démarrage du traitement en temps réel"""
        print("🚀 Démarrage du processeur Kafka-Spark...")
        
        # Lecture des données crypto depuis Kafka
        kafka_raw = self.read_kafka_stream("crypto-prices")
        crypto_data = self.parse_crypto_data(kafka_raw)
        
        # Calcul des indicateurs techniques
        technical_data = self.calculate_technical_indicators(crypto_data)
        
        # Détection d'alertes
        alerts_data = self.detect_alerts(crypto_data)
        
        # Sauvegarde des prix dans DuckDB
        prices_query = crypto_data.select(
            "timestamp", "symbol", "name", "current_price", 
            "market_cap", "total_volume", "price_change_24h", 
            "price_change_percentage_24h"
        ).writeStream \
            .foreachBatch(self.save_to_duckdb("crypto_prices")) \
            .outputMode("append") \
            .trigger(processingTime='30 seconds') \
            .start()
        
        # Sauvegarde des indicateurs techniques
        technical_query = technical_data.writeStream \
            .foreachBatch(self.save_to_duckdb("technical_indicators")) \
            .outputMode("append") \
            .trigger(processingTime='30 seconds') \
            .start()
        
        # Sauvegarde des alertes
        alerts_query = alerts_data.writeStream \
            .foreachBatch(self.save_to_duckdb("crypto_alerts")) \
            .outputMode("append") \
            .trigger(processingTime='30 seconds') \
            .start()
        
        # Affichage console pour debug
        console_query = technical_data.writeStream \
            .outputMode("append") \
            .format("console") \
            .option("truncate", "false") \
            .trigger(processingTime='60 seconds') \
            .start()
        
        print("✅ Processeur démarré avec succès!")
        print("📊 Indicateurs calculés: SMA, RSI, Volatilité, Signaux de tendance")
        print("🔔 Alertes activées: RSI extrêmes, variations de prix importantes")
        print("💾 Données sauvegardées dans DuckDB: crypto_analytics.db")
        print("🌐 Interface Spark disponible: http://localhost:8080")
        
        # Attendre l'arrêt
        try:
            prices_query.awaitTermination()
        except KeyboardInterrupt:
            print("\n🛑 Arrêt du processeur...")
            prices_query.stop()
            technical_query.stop()
            alerts_query.stop()
            console_query.stop()
            self.spark.stop()
            self.duckdb_conn.close()

if __name__ == "__main__":
    processor = KafkaSparkProcessor()
    processor.start_processing()
