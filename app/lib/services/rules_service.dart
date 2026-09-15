// lib/services/rules_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../model/rule_entry.dart';

class RulesService {
  Future<RulesDictionary> fetchDictionary({String countryCode = 'IN'}) async {
    final uri = Uri.parse(
      '${AppConfig.httpBase}/rules/dictionary?country_code=$countryCode',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load rules dictionary (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['error'] == true) {
      throw Exception('Rules dictionary unavailable right now.');
    }
    return RulesDictionary.fromJson(json);
  }
}