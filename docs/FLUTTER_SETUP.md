# Flutter Setup - Crypto VIZ Mobile App

## 📱 **Installation Flutter**

### **1. Télécharger Flutter SDK**
```bash
# Linux/WSL
cd ~/
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.13.9-stable.tar.xz
tar xf flutter_linux_3.13.9-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"

# Ajouter au .bashrc pour permanence
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### **2. Vérifier l'installation**
```bash
flutter doctor
# Installe les dépendances manquantes
flutter doctor --android-licenses
```

### **3. Créer le projet Flutter**
```bash
cd ~/Projects/T-DAT-901-PAR_10/
flutter create crypto_viz_app
cd crypto_viz_app
```

## 🔧 **Configuration du projet**

### **pubspec.yaml - Dépendances**
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0              # Appels API CoinGecko
  fl_chart: ^0.64.0         # Graphiques crypto
  web_socket_channel: ^2.4.0  # WebSocket temps réel
  provider: ^6.0.5          # Gestion d'état
  shared_preferences: ^2.2.2  # Stockage local
  intl: ^0.18.1             # Formatage dates/nombres
  cupertino_icons: ^1.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
```

## 📁 **Structure du projet Flutter**

```
crypto_viz_app/
├── lib/
│   ├── main.dart                 # Point d'entrée
│   ├── models/
│   │   ├── crypto_model.dart     # Modèle de données crypto
│   │   └── price_data.dart       # Données de prix
│   ├── services/
│   │   ├── coingecko_service.dart  # API CoinGecko
│   │   └── websocket_service.dart  # Streaming temps réel
│   ├── providers/
│   │   └── crypto_provider.dart    # Gestion d'état
│   ├── screens/
│   │   ├── home_screen.dart        # Écran principal
│   │   ├── crypto_detail_screen.dart  # Détail crypto
│   │   └── settings_screen.dart    # Paramètres
│   ├── widgets/
│   │   ├── crypto_card.dart        # Carte crypto
│   │   ├── price_chart.dart        # Graphique prix
│   │   └── trending_list.dart      # Liste trending
│   └── utils/
│       ├── constants.dart          # Constantes
│       └── helpers.dart           # Fonctions utilitaires
├── assets/
│   └── icons/                     # Icônes crypto
└── android/                      # Configuration Android
```

## 🚀 **Commandes de développement**

```bash
# Lancer en mode debug
flutter run

# Build pour Android
flutter build apk

# Build pour iOS (sur macOS)
flutter build ios

# Tests
flutter test

# Analyser le code
flutter analyze
```

## 📊 **API CoinGecko - Endpoints utilisés**

```dart
// Prix en temps réel
GET /api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd

// Top cryptos par market cap
GET /api/v3/coins/markets?vs_currency=usd&order=market_cap_desc

// Trending cryptos
GET /api/v3/search/trending

// Données historiques
GET /api/v3/coins/{id}/market_chart?vs_currency=usd&days=7
```
