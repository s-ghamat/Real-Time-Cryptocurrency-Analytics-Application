#!/usr/bin/env python3
"""
Processeur Spark pour l'analyse des données crypto en temps réel
Inspiré de l'exemple WordCount du bootstrap
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import os

class CryptoSparkProcessor:
    def __init__(self):
        self.spark = SparkSession.builder \
            .appName("CryptoAnalyzer") \
            .master(os.environ.get("SPARK_MASTER_URL", "local[*]")) \
            .getOrCreate()
        
        # Schéma pour les données crypto
        self.crypto_schema = StructType([
            StructField("timestamp", TimestampType(), True),
            StructField("symbol", StringType(), True),
            StructField("price", DoubleType(), True),
            StructField("source", StringType(), True)
        ])
    
    def load_crypto_data(self, file_path):
        """Chargement des données crypto depuis CSV"""
        return self.spark.read \
            .option("header", "true") \
            .schema(self.crypto_schema) \
            .csv(file_path)
    
    def calculate_price_changes(self, df):
        """Calcul des variations de prix"""
        # Fenêtre pour calculer les variations
        window_spec = Window.partitionBy("symbol").orderBy("timestamp")
        
        return df.withColumn(
            "previous_price", 
            lag("price").over(window_spec)
        ).withColumn(
            "price_change", 
            col("price") - col("previous_price")
        ).withColumn(
            "price_change_percent",
            (col("price_change") / col("previous_price")) * 100
        )
    
    def get_top_movers(self, df, limit=5):
        """Top des cryptos avec plus forte variation"""
        return df.filter(col("price_change_percent").isNotNull()) \
            .groupBy("symbol") \
            .agg(
                avg("price_change_percent").alias("avg_change_percent"),
                last("price").alias("current_price")
            ) \
            .orderBy(desc("avg_change_percent")) \
            .limit(limit)
    
    def real_time_analysis(self, input_path, output_path):
        """Analyse en temps réel avec sauvegarde"""
        df = self.load_crypto_data(input_path)
        
        # Traitement des données
        df_with_changes = self.calculate_price_changes(df)
        top_movers = self.get_top_movers(df_with_changes)
        
        # Sauvegarde des résultats
        top_movers.coalesce(1).write \
            .mode("overwrite") \
            .option("header", "true") \
            .csv(output_path)
        
        return top_movers
    
    def stream_processing(self):
        """Traitement en streaming (simulation)"""
        # Configuration pour le streaming
        streaming_df = self.spark \
            .readStream \
            .option("header", "true") \
            .schema(self.crypto_schema) \
            .csv("work/crypto_stream/")
        
        # Agrégations en temps réel
        result = streaming_df \
            .groupBy("symbol", window(col("timestamp"), "1 minute")) \
            .agg(
                avg("price").alias("avg_price"),
                count("*").alias("count")
            )
        
        # Output vers console pour debug
        query = result.writeStream \
            .outputMode("update") \
            .format("console") \
            .trigger(processingTime='10 seconds') \
            .start()
        
        return query
    
    def close(self):
        """Fermeture de la session Spark"""
        self.spark.stop()

if __name__ == "__main__":
    processor = CryptoSparkProcessor()
    
    # Test avec des données d'exemple
    print("Démarrage de l'analyse Spark...")
    
    # Exemple d'utilisation
    try:
        # Analyse batch
        results = processor.real_time_analysis(
            "work/crypto_prices.csv", 
            "work/analysis_results"
        )
        results.show()
        
        print("Analyse terminée avec succès")
    except Exception as e:
        print(f"Erreur: {e}")
    finally:
        processor.close()
