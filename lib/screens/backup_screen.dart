import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/services/database_service.dart';
import 'package:ouroboros_mobile/providers/auth_provider.dart';
import 'package:ouroboros_mobile/models/backup_model.dart';
import 'package:ouroboros_mobile/models/data_models.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/providers/planning_provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/all_subjects_provider.dart';
import 'package:ouroboros_mobile/providers/history_provider.dart';
import 'package:ouroboros_mobile/providers/review_provider.dart';
import 'package:ouroboros_mobile/widgets/confirmation_modal.dart';
import 'package:ouroboros_mobile/widgets/catalog_import_loading_screen.dart';
import 'package:ouroboros_mobile/screens/sync_screen.dart';

import 'package:shared_preferences/shared_preferences.dart'; // Necessário para o DatabaseService

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = false;
  // ... (código existente)

  Future<void> _handleExport() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.name;
      if (userId == null) {
        throw Exception('Usuário não encontrado.');
      }

      final backupData = await DatabaseService.instance.exportBackupData(userId);

      // 4. Converter para JSON e salvar
      final jsonString = jsonEncode(backupData.toMap());
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd_HH-mm').format(now);
      final fileName = 'ouroboros_backup_$formattedDate.json';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar Backup',
        fileName: fileName,
        bytes: utf8.encode(jsonString),
      );

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup exportado com sucesso para: $result'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Exportação cancelada.')),
          );
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleImport() async {
    final BuildContext backupScreenContext = context;
    showDialog(
      context: backupScreenContext,
      builder: (BuildContext dialogContext) {
        return ConfirmationModal(
          title: 'Confirmar Importação',
          message: 'A importação de um arquivo substituirá todos os dados atuais. Esta ação é irreversível. Deseja continuar?',
          confirmText: 'Importar e Substituir',
          onConfirm: () async {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop(); // Fecha o modal de confirmação
            }
            if (_isLoading) return;

            setState(() { _isLoading = true; });

            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
              );

              if (result == null || result.files.single.path == null) {
                if (backupScreenContext.mounted) {
                  ScaffoldMessenger.of(backupScreenContext).showSnackBar(
                    const SnackBar(content: Text('Importação cancelada.')),
                  );
                }
                if (mounted) { setState(() => _isLoading = false); }
                return;
              }

              final file = File(result.files.single.path!);
              final jsonString = await file.readAsString();
              final backupData = BackupData.fromMap(jsonDecode(jsonString));

              final authProvider = Provider.of<AuthProvider>(backupScreenContext, listen: false);
              final userId = authProvider.currentUser?.name;
              if (userId == null) {
                throw Exception('Usuário não encontrado.');
              }

              final db = DatabaseService.instance;
              final prefs = await SharedPreferences.getInstance();
              await db.deleteAllDataForUser(userId);
              await db.importBackupData(backupData, userId);

              // 1. Definir o plano ativo com base nos dados importados
              final activePlanProvider = Provider.of<ActivePlanProvider>(backupScreenContext, listen: false);
              if (backupData.plans.isNotEmpty) {
                  final oldActivePlanId = prefs.getString('active_plan_id_${userId}');
                  String newActivePlanIdToSet = backupData.plans.first.id; // Padrão para o primeiro plano

                  if (oldActivePlanId != null && backupData.plans.any((p) => p.id == oldActivePlanId)) {
                      newActivePlanIdToSet = oldActivePlanId; // Preservar o plano ativo antigo se ele estiver no backup
                  }
                  await prefs.setString('active_plan_id_${userId}', newActivePlanIdToSet);
              } else {
                  await prefs.remove('active_plan_id_${userId}'); // Nenhum plano, limpar ativo
              }

              for (var entry in backupData.planningDataPerPlan.entries) {
                final planId = entry.key;
                final planningData = entry.value;
                if (planningData.studyCycle != null) {
                  await prefs.setString('${userId}_studyCycle_$planId', jsonEncode(planningData.studyCycle!.map((s) => s.toJson()).toList()));
                }
                await prefs.setInt('${userId}_completedCycles_$planId', planningData.completedCycles);
                await prefs.setInt('${userId}_currentProgressMinutes_$planId', planningData.currentProgressMinutes);
                await prefs.setString('${userId}_sessionProgressMap_$planId', jsonEncode(planningData.sessionProgressMap));
                await prefs.setString('${userId}_studyHours_$planId', planningData.studyHours);
                await prefs.setString('${userId}_weeklyQuestionsGoal_$planId', planningData.weeklyQuestionsGoal);
                await prefs.setString('${userId}_subjectSettings_$planId', jsonEncode(planningData.subjectSettings));
                await prefs.setStringList('${userId}_studyDays_$planId', planningData.studyDays);
                if (planningData.cycleGenerationTimestamp != null) {
                  await prefs.setString('${userId}_cycleGenerationTimestamp_$planId', planningData.cycleGenerationTimestamp!);
                }
              }

              await Provider.of<PlansProvider>(backupScreenContext, listen: false).fetchPlans();
              await Provider.of<AllSubjectsProvider>(backupScreenContext, listen: false).fetchData();
              await Provider.of<HistoryProvider>(backupScreenContext, listen: false).fetchHistory();
              await Provider.of<ReviewProvider>(backupScreenContext, listen: false).fetchReviews();
              
              // NEW: Refresh ActivePlanProvider state
              await Provider.of<ActivePlanProvider>(backupScreenContext, listen: false).refreshActivePlan();
              
              await Provider.of<PlanningProvider>(backupScreenContext, listen: false).loadData();

              if (backupScreenContext.mounted) {
                ScaffoldMessenger.of(backupScreenContext).showSnackBar(
                  const SnackBar(
                    content: Text('Dados importados com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }

            } catch (e) {
              if (backupScreenContext.mounted) {
                ScaffoldMessenger.of(backupScreenContext).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao importar dados: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (mounted) { setState(() { _isLoading = false; }); }
            }
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }

  Future<void> _handleSyncSubjects() async {
    // A importação inicial do catálogo agora é feita automaticamente na criação do DB.
    // Esta função pode ser revisada se uma funcionalidade de "atualização" for desejada.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catálogo de matérias já é sincronizado automaticamente na inicialização.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  void _handleDeleteAll() {
    final BuildContext backupScreenContext = context;
    showDialog(
      context: backupScreenContext,
      builder: (BuildContext dialogContext) {
        return ConfirmationModal(
          title: 'Apagar Todos os Dados?',
          message: 'ATENÇÃO: Esta ação é irreversível e apagará permanentemente todos os seus dados. Use com extrema cautela.',
          confirmText: 'Apagar Tudo',
          onConfirm: () async {
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop(); // Fecha o modal antes de iniciar
            }
            setState(() { _isLoading = true; });

            try {
              final authProvider = Provider.of<AuthProvider>(backupScreenContext, listen: false);
              final userId = authProvider.currentUser?.name;
              if (userId == null) {
                throw Exception('Usuário não encontrado.');
              }
              await DatabaseService.instance.deleteAllDataForUser(userId);
              await Provider.of<PlanningProvider>(backupScreenContext, listen: false).clearAllData();

              Provider.of<ActivePlanProvider>(backupScreenContext, listen: false).clearActivePlan();
              await Provider.of<PlansProvider>(backupScreenContext, listen: false).fetchPlans();
              await Provider.of<AllSubjectsProvider>(backupScreenContext, listen: false).fetchData();
              await Provider.of<HistoryProvider>(backupScreenContext, listen: false).fetchHistory();
              await Provider.of<ReviewProvider>(backupScreenContext, listen: false).fetchReviews();
              
              if (backupScreenContext.mounted) {
                ScaffoldMessenger.of(backupScreenContext).showSnackBar(
                  const SnackBar(
                    content: Text('Todos os dados foram apagados com sucesso.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }

            } catch (e) {
              if (backupScreenContext.mounted) {
                ScaffoldMessenger.of(backupScreenContext).showSnackBar(
                  SnackBar(
                    content: Text('Ocorreu um erro ao apagar os dados: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (mounted) { // Usamos o contexto original da tela para o setState
                setState(() { _isLoading = false; });
              }
            }
          },
          onClose: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildExportCard(context),
            const SizedBox(height: 16),
            _buildImportCard(context),
            const SizedBox(height: 16),
            _buildSyncCard(context),
            const SizedBox(height: 16),
            _buildLocalSyncCard(context),
            const SizedBox(height: 16),
            _buildDeleteCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, Icons.sync, 'Sincronizar Catálogo', Colors.blueAccent),
            const SizedBox(height: 8),
            Text(
              'Carrega e atualiza o catálogo de matérias e assuntos disponíveis no aplicativo. Execute esta ação se as matérias não estiverem aparecendo.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleSyncSubjects,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)) : const Icon(Icons.sync),
              label: Text(_isLoading ? 'Sincronizando...' : 'Sincronizar Catálogo Agora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.teal, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, Icons.download, 'Exportar Dados', Colors.teal),
            const SizedBox(height: 8),
            Text(
              'Crie um backup de todos os seus dados. Salve este arquivo em um local seguro.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleExport,
              icon: const Icon(Icons.download),
              label: const Text('Exportar para Arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.teal, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, Icons.upload, 'Importar Dados', Colors.teal),
            const SizedBox(height: 16),
            _buildWarningBox(
              title: 'Atenção!',
              message: 'A importação de um arquivo substituirá permanentemente todos os dados atuais. Use com cuidado.',
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleImport,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)) : const Icon(Icons.upload),
              label: Text(_isLoading ? 'Importando...' : 'Importar de Arquivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, Icons.warning, 'Começar do Zero', Colors.red),
            const SizedBox(height: 16),
            _buildWarningBox(
              title: 'ATENÇÃO: Esta ação é irreversível!',
              message: 'Todos os seus dados serão PERMANENTEMENTE apagados. Use com extrema cautela.',
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleDeleteAll,
              icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal)) : const Icon(Icons.delete_forever),
              label: Text(_isLoading ? 'Apagando Dados...' : 'Começar do Zero'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalSyncCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: const BorderSide(color: Colors.blueGrey, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(context, Icons.sync_alt, 'Sincronização Local', Colors.blueGrey),
            const SizedBox(height: 8),
            Text(
              'Sincronize seus dados entre dispositivos na mesma rede Wi-Fi.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SyncScreen()),
                );
              },
              icon: const Icon(Icons.sync_alt),
              label: const Text('Acessar Sincronização Local'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTitle(BuildContext context, IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildWarningBox({required String title, required String message, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}