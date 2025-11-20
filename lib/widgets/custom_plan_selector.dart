import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ouroboros_mobile/providers/plans_provider.dart';
import 'package:ouroboros_mobile/providers/active_plan_provider.dart';
import 'package:ouroboros_mobile/models/data_models.dart'; // Importar Plan

class CustomPlanSelector extends StatefulWidget {
  const CustomPlanSelector({Key? key}) : super(key: key);

  @override
  State<CustomPlanSelector> createState() => _CustomPlanSelectorState();
}

class _CustomPlanSelectorState extends State<CustomPlanSelector> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void _showOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: 200, // Largura fixa para o balão
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0.0, -8.0), // Pequeno espaçamento entre o botão e o dropdown
          child: Material(
            color: Colors.transparent, // Fundo transparente para o Material
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, // Fundo branco
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.teal), // Borda teal
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Consumer2<PlansProvider, ActivePlanProvider>(
                builder: (context, plansProvider, activePlanProvider, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: plansProvider.plans.map((plan) {
                      return ListTile(
                        title: Text(
                          plan.name,
                          style: const TextStyle(color: Colors.teal), // Texto teal
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          activePlanProvider.setActivePlan(plan.id);
                          _hideOverlay();
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlansProvider, ActivePlanProvider>(
      builder: (context, plansProvider, activePlanProvider, child) {
        String? currentPlanId = activePlanProvider.activePlanId;
        Plan? selectedPlan = plansProvider.plans.firstWhereOrNull(
          (p) => p.id == currentPlanId,
        );

        return GestureDetector(
          onTap: () {
            if (plansProvider.plans.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Crie ou importe um plano primeiro!'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (_overlayEntry == null) {
              _showOverlay();
            } else {
              _hideOverlay();
            }
          },
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.white, // Fundo branco em ambos os modos
                borderRadius: BorderRadius.circular(20.0), // Borda arredondada para cápsula
                border: Border.all(color: Colors.teal), // Borda sempre teal
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedPlan?.name ?? 'Selecione um Plano',
                    style: const TextStyle(color: Colors.teal, fontSize: 16.0), // Texto sempre teal
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.teal), // Ícone sempre teal
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
