import 'package:flutter/material.dart';

class CatalogImportLoadingScreen extends StatefulWidget {
  const CatalogImportLoadingScreen({super.key});

  @override
  State<CatalogImportLoadingScreen> createState() =>
      _CatalogImportLoadingScreenState();
}

class _CatalogImportLoadingScreenState extends State<CatalogImportLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDarkMode
        ? 'logo/logo-modo-escuro.png'
        : 'logo/logo.png';

    return Scaffold(
      backgroundColor: isDarkMode
          ? Colors.black.withOpacity(0.8)
          : Colors.white.withOpacity(0.8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _controller,
                child: Image.asset(logoAsset, height: 80, width: 80),
              ),
              const SizedBox(height: 24),
              Text(
                'Sincronizando Catálogo...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aguarde um momento, estamos preparando tudo para você.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                backgroundColor: Colors
                    .tealAccent, // Adiciona um fundo para a barra de progresso
              ),
            ],
          ),
        ),
      ),
    );
  }
}
