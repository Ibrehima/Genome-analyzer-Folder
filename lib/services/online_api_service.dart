import 'dart:convert';
import 'package:http/http.dart' as http;

/// Wrapper around genuinely public, key-free bioinformatics REST APIs.
/// These calls are attempted only when connectivity is available; failures
/// (including browser CORS restrictions on Web) are caught gracefully so the
/// app can fall back to the local offline engines or to the "Online Tools
/// Hub" deep-links where the user can use the provider's full website.
class OnlineApiService {
  static const _timeout = Duration(seconds: 10);

  /// GBIF species/taxonomy match — supports CORS, works well from Web.
  static Future<Map<String, dynamic>?> gbifSpeciesMatch(String name) async {
    try {
      final uri = Uri.parse(
        'https://api.gbif.org/v1/species/match?name=${Uri.encodeComponent(name)}',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Network / CORS failure — caller should fall back gracefully.
    }
    return null;
  }

  /// GBIF occurrence search by scientific name (returns raw counts + sample records).
  static Future<Map<String, dynamic>?> gbifOccurrenceSearch(
    String scientificName,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.gbif.org/v1/occurrence/search?scientificName=${Uri.encodeComponent(scientificName)}&limit=5',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// UniProt REST search (protein records) — generally CORS-enabled.
  static Future<List<dynamic>?> uniprotSearch(
    String query, {
    int size = 5,
  }) async {
    try {
      final uri = Uri.parse(
        'https://rest.uniprot.org/uniprotkb/search?query=${Uri.encodeComponent(query)}&size=$size&format=json&fields=accession,id,protein_name,organism_name,length',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['results'] as List<dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  /// Ensembl REST — species/gene lookup by symbol.
  static Future<Map<String, dynamic>?> ensemblLookupSymbol(
    String symbol, {
    String species = 'homo_sapiens',
  }) async {
    try {
      final uri = Uri.parse(
        'https://rest.ensembl.org/lookup/symbol/$species/${Uri.encodeComponent(symbol)}?content-type=application/json',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// NCBI E-utilities ESearch (may be blocked by CORS on Web; works on Android).
  static Future<List<String>?> ncbiEsearch({
    required String db,
    required String term,
  }) async {
    try {
      final uri = Uri.parse(
        'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=$db&term=${Uri.encodeComponent(term)}&retmode=json&retmax=10',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final idlist = (data['esearchresult']?['idlist'] as List?)
            ?.cast<String>();
        return idlist;
      }
    } catch (_) {}
    return null;
  }

  /// NCBI E-utilities EFetch — retrieve FASTA for a given UID.
  static Future<String?> ncbiEfetchFasta({
    required String db,
    required String id,
  }) async {
    try {
      final uri = Uri.parse(
        'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=$db&id=$id&rettype=fasta&retmode=text',
      );
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        return res.body;
      }
    } catch (_) {}
    return null;
  }
}
