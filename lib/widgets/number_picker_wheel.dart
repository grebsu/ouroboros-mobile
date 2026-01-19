import 'package:flutter/material.dart';

class NumberPickerWheel extends StatefulWidget {
  final int minValue;
  final int maxValue;
  final int initialValue;
  final ValueChanged<int> onChanged;
  final double itemExtent;
  final double diameterRatio;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;

  const NumberPickerWheel({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    required this.onChanged,
    this.itemExtent = 40.0,
    this.diameterRatio = 1.1,
    this.textStyle,
    this.padding,
  });

  @override
  State<NumberPickerWheel> createState() => _NumberPickerWheelState();
}

class _NumberPickerWheelState extends State<NumberPickerWheel> {
  late FixedExtentScrollController _scrollController;
  late int _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _scrollController = FixedExtentScrollController(
      initialItem: _currentValue - widget.minValue,
    );
  }

  @override
  void didUpdateWidget(covariant NumberPickerWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _currentValue) {
      _currentValue = widget.initialValue;
      _scrollController.jumpToItem(_currentValue - widget.minValue);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: widget.padding,
      height: widget.itemExtent * 3, // Show 3 items at a time
      child: ListWheelScrollView.useDelegate(
        controller: _scrollController,
        itemExtent: widget.itemExtent,
        diameterRatio: widget.diameterRatio,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          final range = widget.maxValue - widget.minValue + 1;
          final newValue = widget.minValue + (index % range);
          if (newValue != _currentValue) {
            setState(() {
              _currentValue = newValue;
            });
            widget.onChanged(newValue);
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final range = widget.maxValue - widget.minValue + 1;
            final value = widget.minValue + (index % range);
            return Center(
              child: Text(
                value.toString().padLeft(2, '0'),
                style:
                    widget.textStyle ??
                    Theme.of(context).textTheme.headlineMedium,
              ),
            );
          },
          childCount: null, // This makes it loop
        ),
      ),
    );
  }
}
