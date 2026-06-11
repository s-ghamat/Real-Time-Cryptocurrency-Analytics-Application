# Xtreme Dashboarding

Real-time big data monitoring system for cryptocurrency news flows.

The project collects crypto-related news, processes the stream with Apache Spark, stores the results and displays analytics through an interactive dashboard.

## Overview

Xtreme Dashboarding is designed as a streaming analytics platform.

It follows a simple big data pipeline:

```text
Data Sources → Kafka → Spark → Storage → Dashboard
```

## Goals

* Collect cryptocurrency news continuously
* Stream data through Apache Kafka
* Process and analyze events with Apache Spark
* Store structured results
* Display live metrics and visualizations
* Provide a reproducible Docker-based environment

## Architecture

| Layer          | Role                                    |
| -------------- | --------------------------------------- |
| Data ingestion | Collect news data from external sources |
| Kafka          | Stream events between services          |
| Spark          | Process and analyze incoming data       |
| Storage        | Persist processed results               |
| Dashboard      | Visualize metrics and trends            |
| Docker         | Run the platform consistently           |

## Technologies

* Apache Kafka
* Apache Spark
* Docker
* Python
* Grafana
* Plotly

## Project Structure

```text
.
├── data-ingestion/
├── kafka/
├── spark/
├── storage/
├── dashboard/
├── docker/
└── docs/
```

## Components

### Data Ingestion

Python scripts collect cryptocurrency news from selected sources and publish events to Kafka topics.

### Kafka

Kafka handles the real-time data stream between ingestion services and processing jobs.

### Spark

Spark jobs consume Kafka events, transform the data, and compute analytics.

### Storage

Processed data is stored for dashboard consumption and later analysis.

### Dashboard

The dashboard provides live visualizations for cryptocurrency news activity, trends, and monitoring metrics.

### Docker

Docker configuration is used to simplify deployment and make the environment reproducible.

## Usage

Start the platform from the Docker configuration:

```sh
docker compose up --build
```

Run the data ingestion service:

```sh
python data-ingestion/main.py
```

Run the Spark processing job:

```sh
python spark/main.py
```

Open the dashboard according to the dashboard service configuration.

## Documentation

Additional setup notes, architecture details, and operating instructions are available in:

```text
docs/
```

## Author

Setayesh Ghamat
