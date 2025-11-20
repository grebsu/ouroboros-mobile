import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text(
              'Apoie a Missão Ouroboros',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Ouroboros é uma aplicação open-source e gratuita de planejamento de estudos, com foco na democratização do acesso a ferramentas de alta performance para estudantes e concurseiros.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sua doação nos ajuda a manter e evoluir a plataforma, apoiando diretamente estudantes hipossuficientes a terem acesso a recursos de qualidade para transformar seu futuro.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: Image.asset(
                'logo/qrcode-pix.png',
                width: 256,
                height: 256,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Escaneie o QR code com seu aplicativo de banco.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.teal),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      persistentFooterButtons: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar Chave PIX (E-mail)'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'ouroboros743@gmail.com'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chave PIX copiada!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        )
      ],
    );
  }
}