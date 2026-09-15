// lib/model/rule_entry.dart
class RuleEntry {
  final String id;
  final String category;
  final String rule;
  final String redFlagContext;
  final String source;
  final String sourceUrl;

  RuleEntry({
    required this.id,
    required this.category,
    required this.rule,
    required this.redFlagContext,
    required this.source,
    required this.sourceUrl,
  });

  factory RuleEntry.fromJson(Map<String, dynamic> json) {
    return RuleEntry(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      redFlagContext: json['red_flag_context'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sourceUrl: json['source_url'] as String? ?? '',
    );
  }
}

class RulesDictionary {
  final String countryName;
  final Map<String, String> emergencyContacts;
  final List<RuleEntry> entries;
  final List<String> universalPatterns;

  RulesDictionary({
    required this.countryName,
    required this.emergencyContacts,
    required this.entries,
    required this.universalPatterns,
  });

  factory RulesDictionary.fromJson(Map<String, dynamic> json) {
    final contactsJson =
        json['emergency_contacts'] as Map<String, dynamic>? ?? {};
    return RulesDictionary(
      countryName: json['country_name'] as String? ?? '',
      emergencyContacts:
          contactsJson.map((k, v) => MapEntry(k, v.toString())),
      entries: (json['entries'] as List<dynamic>? ?? [])
          .map((e) => RuleEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      universalPatterns:
          (json['universal_fallback_patterns'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
    );
  }
}