import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crypto_provider.dart';
import '../widgets/dark_crypto_card.dart';
import '../widgets/dark_news_card.dart';
import '../widgets/market_overview_charts.dart';
import '../widgets/enhanced_crypto_card.dart';
import '../screens/analytics_screen.dart';
import '../screens/creative_charts_screen.dart';
import '../utils/formatters.dart';

class DarkHomeScreen extends StatefulWidget {
  const DarkHomeScreen({super.key});

  @override
  State<DarkHomeScreen> createState() => _DarkHomeScreenState();
}

class _DarkHomeScreenState extends State<DarkHomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CryptoProvider>().loadInitialData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: Column(
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2139),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Contenu principal avec PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                children: [
                  _buildPortfolioPage(),
                  _buildNewsPage(),
                  _buildStatsPage(),
                  _buildProfilePage(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E2139),
          border: Border(
            top: BorderSide(color: Color(0xFF2A2D47), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF4A90E2),
          unselectedItemColor: const Color(0xFF8B93A7),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article_outlined),
              activeIcon: Icon(Icons.article),
              label: 'News',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.apps_outlined),
              activeIcon: Icon(Icons.apps),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Salutation et balance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hi, Julien!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back to your portfolio',
                  style: TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 30),

                // Balance principale
                Consumer<CryptoProvider>(
                  builder: (context, provider, child) {
                    final totalValue = provider.cryptos.isNotEmpty
                        ? provider.cryptos
                            .take(5)
                            .fold(0.0, (sum, crypto) => sum + crypto.currentPrice)
                        : 69420.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Formatters.formatCurrency(totalValue),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '+5.842',
                                style: TextStyle(
                                  color: Color(0xFF4CAF50),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '+8.2%',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Graphique principal
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2139),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2D47)),
                  ),
                  child: CustomPaint(
                    painter: MainChartPainter(),
                    size: const Size(double.infinity, 160),
                  ),
                ),

                const SizedBox(height: 30),

                // Statistiques
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'INCOME',
                        '+262,144',
                        const Color(0xFF4CAF50),
                        true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'OUTCOME',
                        '65,536',
                        const Color(0xFFFF5252),
                        false,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const Text(
                  'My Assets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Liste des cryptos
          Consumer<CryptoProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.cryptos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                    ),
                  ),
                );
              }

              if (provider.error.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Color(0xFFFF5252),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Erreur lors du chargement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error,
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => provider.fetchTopCryptos(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Réessayer'),
                        ),
                        if (provider.error.contains('429') ||
                            provider.error.contains('Limite'))
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              '💡 Astuce: Assurez-vous que l\'API Gateway est lancée\npour utiliser les données depuis Kafka',
                              style: TextStyle(
                                color: Color(0xFF8B93A7),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }

              final cryptosToShow = provider.filteredCryptos.isEmpty
                  ? provider.cryptos
                  : provider.filteredCryptos;

              return Column(
                children: cryptosToShow
                    .map((crypto) => EnhancedCryptoCard(crypto: crypto))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNewsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Crypto News',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Consumer<CryptoProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingNews && provider.news.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                    ),
                  ),
                );
              }

              if (provider.news.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: Color(0xFF8B93A7),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No news available',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchCryptoNews(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: provider.news
                    .map((news) => DarkNewsCard(news: news))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Market Analytics',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Bouton pour accéder aux analytics avancés
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
              label: const Text('Advanced Analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Graphiques de vue d'ensemble du marché
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Consumer<CryptoProvider>(
              builder: (context, provider, child) {
                if (provider.cryptos.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                    ),
                  );
                }

                return MarketOverviewCharts(cryptos: provider.cryptos);
              },
            ),
          ),

          const SizedBox(height: 20),

          // Métriques de marché rapides
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Consumer<CryptoProvider>(
              builder: (context, provider, child) {
                if (provider.cryptos.isEmpty) return const SizedBox();

                final totalMarketCap = provider.cryptos.fold<double>(
                    0, (sum, crypto) => sum + crypto.marketCap);
                final avgChange = provider.cryptos.fold<double>(
                        0,
                        (sum, crypto) =>
                            sum + crypto.priceChangePercentage24h) /
                    provider.cryptos.length;

                return Row(
                  children: [
                    Expanded(
                      child: _buildQuickStatCard(
                        'Total Market Cap',
                        '\$${(totalMarketCap / 1000000000000).toStringAsFixed(2)}T',
                        avgChange >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        avgChange >= 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickStatCard(
                        'Avg 24h Change',
                        '${avgChange >= 0 ? '+' : ''}${avgChange.toStringAsFixed(2)}%',
                        avgChange >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        avgChange >= 0,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'More',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),

            // Bouton Analytics
            _buildMenuCard(
              icon: Icons.analytics,
              title: 'Advanced Analytics',
              subtitle: 'Technical indicators and market analysis',
              color: const Color(0xFF50C878),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Nouveau bouton : Creative Charts
            _buildMenuCard(
              icon: Icons.auto_graph_rounded,
              title: 'Creative Crypto Charts',
              subtitle: 'Graphiques originaux et visuels',
              color: const Color(0xFF4A90E2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreativeChartsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Autres options
            _buildMenuCard(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'App preferences and configuration',
              color: const Color(0xFF8B93A7),
              onTap: () {
                // TODO: Implémenter la page de paramètres
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings coming soon'),
                    backgroundColor: Color(0xFF1E2139),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2139),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D47)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF8B93A7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${isPositive ? '+' : ''}$value',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: color,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(
      String title, String value, Color color, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MainChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Génère une courbe ascendante
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.45, size.height * 0.4),
      Offset(size.width * 0.6, size.height * 0.5),
      Offset(size.width * 0.75, size.height * 0.3),
      Offset(size.width, size.height * 0.2),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    // Zone sous la courbe
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4A90E2).withOpacity(0.3),
          const Color(0xFF4A90E2).withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Point actuel
    final pointPaint = Paint()
      ..color = const Color(0xFF4A90E2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 4, pointPaint);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 2, whitePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}