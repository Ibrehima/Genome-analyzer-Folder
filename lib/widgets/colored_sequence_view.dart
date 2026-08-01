import 'package:flutter/material.dart';

/// Renders a biological sequence (or aligned sequence with gaps) with
/// per-base color coding, in a horizontally scrollable monospace view.
class ColoredSequenceView extends StatelessWidget {
  final String sequence;
  final double fontSize;
  final int? highlightStart;
  final int? highlightEnd;

  const ColoredSequenceView({
    super.key,
    required this.sequence,
    this.fontSize = 13,
    this.highlightStart,
    this.highlightEnd,
  });

  static const Map<String, Color> baseColors = {
    'A': Color(0xFF2E7D32),
    'T': Color(0xFFC62828),
    'U': Color(0xFFC62828),
    'G': Color(0xFF1565C0),
    'C': Color(0xFFEF6C00),
    'N': Color(0xFF9E9E9E),
    '-': Color(0xFFBDBDBD),
    '*': Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: RichText(
        text: TextSpan(
          children: List.generate(sequence.length, (i) {
            final c = sequence[i];
            final isHighlighted =
                highlightStart != null &&
                highlightEnd != null &&
                i >= highlightStart! &&
                i < highlightEnd!;
            return TextSpan(
              text: c,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: baseColors[c] ?? Colors.black87,
                backgroundColor: isHighlighted ? const Color(0xFFFFF9C4) : null,
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Small legend row explaining base color codes.
class SequenceLegend extends StatelessWidget {
  final bool isProtein;
  const SequenceLegend({super.key, this.isProtein = false});

  @override
  Widget build(BuildContext context) {
    final entries = isProtein
        ? const [('Sequence', Color(0xFF37474F))]
        : const [
            ('A', Color(0xFF2E7D32)),
            ('T/U', Color(0xFFC62828)),
            ('G', Color(0xFF1565C0)),
            ('C', Color(0xFFEF6C00)),
            ('N/-', Color(0xFF9E9E9E)),
          ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: entries
          .map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  color: e.$2,
                  margin: const EdgeInsets.only(right: 4),
                ),
                Text(
                  e.$1,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}
