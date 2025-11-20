import 'package:flutter/material.dart';
import 'package:ouroboros_mobile/models/data_models.dart';

// Data classes used by the widget
class HierarchicalPerformanceNode {
  final String id;
  final String name;
  final int acertos;
  final int erros;
  final int total;
  final double percentualAcerto;
  final bool isGroupingTopic;
  final int level;
  final List<HierarchicalPerformanceNode> children;

  HierarchicalPerformanceNode({
    required this.id,
    required this.name,
    required this.acertos,
    required this.erros,
    required this.total,
    required this.percentualAcerto,
    required this.isGroupingTopic,
    required this.level,
    this.children = const [],
  });
}

class TopicPerformanceTable extends StatefulWidget {
  final List<HierarchicalPerformanceNode> data;

  const TopicPerformanceTable({super.key, required this.data});

  @override
  _TopicPerformanceTableState createState() => _TopicPerformanceTableState();
}

class _TopicPerformanceTableState extends State<TopicPerformanceTable> {
  late List<HierarchicalPerformanceNode> _flattenedData;
  late Set<String> _expandedNodes;

  @override
  void initState() {
    super.initState();
    _expandedNodes = widget.data.map((e) => e.id).toSet(); // Start with top-level expanded
    _flattenedData = _getFlattenedData();
  }

  List<HierarchicalPerformanceNode> _getFlattenedData() {
    final List<HierarchicalPerformanceNode> flatList = [];
    for (final node in widget.data) {
      _flattenNode(node, flatList);
    }
    return flatList;
  }

  void _flattenNode(HierarchicalPerformanceNode node, List<HierarchicalPerformanceNode> flatList) {
    flatList.add(node);
    if (_expandedNodes.contains(node.id)) {
      for (final child in node.children) {
        _flattenNode(child, flatList);
      }
    }
  }

  void _toggleNode(String nodeId) {
    setState(() {
      if (_expandedNodes.contains(nodeId)) {
        _expandedNodes.remove(nodeId);
      } else {
        _expandedNodes.add(nodeId);
      }
      _flattenedData = _getFlattenedData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _flattenedData.length,
          itemBuilder: (context, index) {
            final node = _flattenedData[index];
            return _buildRow(node);
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Disciplina/Tópico', style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
          Expanded(flex: 2, child: Text('Acertos', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
          Expanded(flex: 2, child: Text('Erros', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
          Expanded(flex: 3, child: Text('Desempenho', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
        ],
      ),
    );
  }

  Widget _buildRow(HierarchicalPerformanceNode node) {
    final theme = Theme.of(context);
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedNodes.contains(node.id);
    final isEvenRow = _flattenedData.indexOf(node) % 2 == 0;

    Color? rowBackgroundColor = node.isGroupingTopic
        ? theme.colorScheme.primary.withOpacity(0.05)
        : (isEvenRow ? theme.colorScheme.surfaceVariant.withOpacity(0.1) : Colors.transparent);

    Color performanceColor;
    if (node.percentualAcerto >= 70) {
      performanceColor = Colors.green.shade700;
    } else if (node.percentualAcerto >= 50) {
      performanceColor = Colors.orange.shade700;
    } else {
      performanceColor = Colors.red.shade700;
    }

    return Column(
      children: [
        InkWell(
          onTap: hasChildren ? () => _toggleNode(node.id) : null,
          child: Container(
            color: rowBackgroundColor,
            padding: EdgeInsets.only(left: 8.0 + (node.level * 16.0), right: 8.0, top: 12.0, bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      if (hasChildren)
                        Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 18, color: theme.textTheme.bodyLarge?.color)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          node.name,
                          style: TextStyle(
                            fontWeight: node.isGroupingTopic ? FontWeight.bold : FontWeight.normal,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text('${node.acertos}', textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color))),
                Expanded(flex: 2, child: Text('${node.erros}', textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color))),
                Expanded(flex: 2, child: Text('${node.total}', textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyLarge?.color))),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      '${node.percentualAcerto.toStringAsFixed(1)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: performanceColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.5)),
      ],
    );
  }
}
