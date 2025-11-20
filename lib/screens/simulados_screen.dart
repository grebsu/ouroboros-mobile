import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/simulado_record.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/simulados_provider.dart';
import 'package:ouroboros_mobile/widgets/simulados/simulado_card.dart';
import 'package:ouroboros_mobile/widgets/simulados/simulado_line_chart.dart';

import 'package:ouroboros_mobile/screens/simulados/add_edit_simulado_screen.dart';

// --- Main Screen Widget ---
class SimuladosScreen extends StatefulWidget {
  const SimuladosScreen({super.key});

  @override
  State<SimuladosScreen> createState() => _SimuladosScreenState();
}

class _SimuladosScreenState extends State<SimuladosScreen> {
  String _chartType = 'desempenho';

  @override
  Widget build(BuildContext context) {
    return Consumer<SimuladosProvider>(
      builder: (context, simuladosProvider, child) {
        final List<SimuladoRecord> simulados = simuladosProvider.simulados;
        final latestSimulado = simulados.isNotEmpty ? simulados.first : null;

        return Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                _buildSummarySection(simulados, latestSimulado), // Passa simulados e latestSimulado
                const SizedBox(height: 24),
                _buildPerformanceChart(context, simulados), // Passa simulados
                const SizedBox(height: 24),
                _buildSimuladosList(simulados), // Passa simulados
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummarySection(List<SimuladoRecord> simulados, SimuladoRecord? latestSimulado) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Simulados Realizados', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    simulados.length.toString(),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (latestSimulado != null)
          Expanded(
            flex: 3,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Último Simulado', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Acertos', latestSimulado.totalCorrect.toString(), Colors.green),
                        _buildStatColumn('Erros', latestSimulado.totalIncorrect.toString(), Colors.red),
                        _buildStatColumn('Brancos', latestSimulado.totalBlank.toString(), Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildPerformanceChart(BuildContext context, List<SimuladoRecord> simulados) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Seu Desempenho', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ToggleButtons(
                  isSelected: [_chartType == 'desempenho', _chartType == 'pontuacao'],
                  onPressed: (index) {
                    setState(() {
                      _chartType = index == 0 ? 'desempenho' : 'pontuacao';
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white, // Texto branco para o selecionado
                  fillColor: Colors.teal, // Fundo teal para o selecionado
                  color: Colors.teal, // Texto teal para o não selecionado
                  borderColor: Colors.teal, // Borda teal para o não selecionado
                  selectedBorderColor: Colors.teal, // Borda teal para o selecionado
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Desempenho')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Pontuação')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: SimuladoLineChart(
                simulados: simulados,
                chartType: _chartType,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimuladosList(List<SimuladoRecord> simulados) {
    if (simulados.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Text('Você ainda não registrou nenhum simulado.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AddEditSimuladoScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Registrar Novo Simulado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: simulados.map((simulado) => SimuladoCard(simulado: simulado)).toList(),
    );
  }
}