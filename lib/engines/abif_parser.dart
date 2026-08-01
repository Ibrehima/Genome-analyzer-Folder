import 'dart:typed_data';

/// Minimal parser for the ABIF binary format used by Applied Biosystems
/// (Sanger / capillary) sequencers to store called bases + quality values
/// (.ab1 files). We only extract the base-call ("PBAS") and per-base
/// quality/confidence ("PCON") tagged records — the sequencer's own
/// basecalling software has already converted the raw fluorescence trace
/// into bases, so no signal-processing/basecalling is attempted here.
class AbifRecord {
  final String bases;
  final List<int> quality;
  AbifRecord({required this.bases, required this.quality});
}

class AbifParser {
  /// Returns null if [bytes] is not a valid ABIF file or the expected
  /// PBAS/PCON tags cannot be located.
  static AbifRecord? parse(Uint8List bytes) {
    if (bytes.length < 34) return null;
    final bd = ByteData.sublistView(bytes);

    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'ABIF') return null;

    // Root directory entry starts right after magic(4)+version(2) = offset 6
    const rootOffset = 6;
    if (bytes.length < rootOffset + 28) return null;
    final numDirEntries = bd.getInt32(rootOffset + 12, Endian.big);
    final dirOffset = bd.getInt32(rootOffset + 20, Endian.big);
    if (numDirEntries <= 0 || dirOffset < 0 || dirOffset > bytes.length) {
      return null;
    }

    String? bestBases;
    int bestBasesTagNum = -1;
    List<int>? bestQuality;
    int bestQualityTagNum = -1;

    for (int i = 0; i < numDirEntries; i++) {
      final entryOffset = dirOffset + i * 28;
      if (entryOffset + 28 > bytes.length) break;
      final name = String.fromCharCodes(
        bytes.sublist(entryOffset, entryOffset + 4),
      );
      final number = bd.getInt32(entryOffset + 4, Endian.big);
      final numElements = bd.getInt32(entryOffset + 12, Endian.big);
      final dataSize = bd.getInt32(entryOffset + 16, Endian.big);
      final dataFieldOffset = entryOffset + 20;

      int actualDataOffset;
      if (dataSize <= 4) {
        actualDataOffset = dataFieldOffset;
      } else {
        actualDataOffset = bd.getInt32(dataFieldOffset, Endian.big);
      }
      if (actualDataOffset < 0 || actualDataOffset + dataSize > bytes.length) {
        continue;
      }

      if (name == 'PBAS' && number >= bestBasesTagNum) {
        bestBases = String.fromCharCodes(
          bytes.sublist(actualDataOffset, actualDataOffset + numElements),
        );
        bestBasesTagNum = number;
      } else if (name == 'PCON' && number >= bestQualityTagNum) {
        bestQuality = bytes
            .sublist(actualDataOffset, actualDataOffset + numElements)
            .map((b) => b) // raw byte 0-255, used directly as Phred-like score
            .toList();
        bestQualityTagNum = number;
      }
    }

    if (bestBases == null || bestBases.isEmpty) return null;
    return AbifRecord(bases: bestBases, quality: bestQuality ?? []);
  }

  /// True if [bytes] look like an ABIF (.ab1) binary trace file.
  static bool looksLikeAbif(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x41 &&
        bytes[1] == 0x42 &&
        bytes[2] == 0x49 &&
        bytes[3] == 0x46; // "ABIF"
  }
}
