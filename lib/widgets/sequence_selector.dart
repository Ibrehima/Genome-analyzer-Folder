import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bio_sequence.dart';
import '../services/app_state.dart';

/// Dropdown-style multi/single sequence selector fed by the shared library.
class SequenceSelector extends StatelessWidget {
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final bool multiple;
  final String label;

  const SequenceSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.multiple = false,
    this.label = 'Select sequence(s)',
  });

  @override
  Widget build(BuildContext context) {
    final sequences = context.watch<AppState>().sequences;

    if (sequences.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFFEF6C00)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No sequences in your library yet. Upload or paste one from the Library tab first.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ...sequences.map((seq) {
          final selected = selectedIds.contains(seq.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                List<String> next;
                if (multiple) {
                  next = List.from(selectedIds);
                  if (selected) {
                    next.remove(seq.id);
                  } else {
                    next.add(seq.id);
                  }
                } else {
                  next = selected ? [] : [seq.id];
                }
                onChanged(next);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFE3F2FD) : Colors.white,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      multiple
                          ? (selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank)
                          : (selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                      size: 20,
                      color: selected ? const Color(0xFF1565C0) : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seq.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            '${seq.type.label} · ${seq.length} bp${seq.hasQuality ? " · FASTQ" : ""}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class SequenceUtil {
  static BioSequence? byId(BuildContext context, String? id) {
    if (id == null) return null;
    return context.read<AppState>().getSequenceById(id);
  }
}
