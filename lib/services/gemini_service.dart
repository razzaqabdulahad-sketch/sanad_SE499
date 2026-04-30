import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/complaint.dart';

class GeminiService {
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent';

  static final RegExp _codeFenceRegex = RegExp(r'```(?:json)?\s*|```');

  static Uri _buildUri() => Uri.parse('$_baseUrl?key=$_apiKey');

  static String _stripCodeFences(String value) {
    return value.replaceAll(_codeFenceRegex, '').trim();
  }

  static String _extractModelText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';

    final first = candidates.first;
    if (first is! Map) return '';

    final content = first['content'];
    if (content is! Map) return '';

    final parts = content['parts'];
    if (parts is! List) return '';

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text.trim());
        }
      }
    }

    return buffer.toString().trim();
  }

  static Map<String, dynamic>? _extractJsonObject(String raw) {
    final stripped = _stripCodeFences(raw);

    try {
      final decoded = jsonDecode(stripped);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      // Continue with substring extraction.
    }

    final jsonStart = stripped.indexOf('{');
    final jsonEnd = stripped.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd <= jsonStart) return null;

    try {
      final decoded = jsonDecode(stripped.substring(jsonStart, jsonEnd + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _extractLabeledValue(String text, String label) {
    try {
      final escapedLabel = RegExp.escape(label);
      final regex = RegExp(
        '^\\s*$escapedLabel\\s*[:=-]\\s*(.+?)\\s*\$',
        caseSensitive: false,
        multiLine: true,
      );
      final match = regex.firstMatch(text);
      return match?.group(1)?.trim();
    } catch (_) {
      return null;
    }
  }

  static String _normalizeTextToken(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _normalizeDepartment(String raw) {
    final normalized = _normalizeTextToken(raw);
    if (normalized.isEmpty) return null;

    if (RegExp(r'\blegal\b').hasMatch(normalized)) return 'legal';
    if (RegExp(r'\bhr\b').hasMatch(normalized) ||
        normalized.contains('human resources') ||
        normalized.contains('human resource')) {
      return 'hr';
    }

    return null;
  }

  static int _normalizeConfidenceScore(String raw) {
    final normalized = _normalizeTextToken(raw);

    if (normalized.contains('high')) return 3;
    if (normalized.contains('medium') || normalized.contains('moderate')) {
      return 2;
    }
    if (normalized.contains('low')) return 1;

    return 2;
  }

  static ({int hrScore, int legalScore}) _scoreDepartmentSignals({
    required String subject,
    required String description,
  }) {
    final text = _normalizeTextToken('$subject $description');

    final legalStrongSignals = <RegExp>[
      RegExp(
        r'\b(fraud|fraudulent|theft|embezzlement|forgery|bribery|corruption|kickback|money laundering)\b',
      ),
      RegExp(
        r'\b(contract dispute|contractual dispute|contract breach|third party dispute|liability|lawsuit|litigation)\b',
      ),
      RegExp(
        r'\b(regulatory violation|regulatory non compliance|legal violation|illegal|legal action|legal investigation)\b',
      ),
      RegExp(
        r'\b(data breach|privacy violation|confidential customer|confidential data|unauthorized disclosure)\b',
      ),
      RegExp(r'\b(intellectual property|copyright|trademark|patent)\b'),
      RegExp(r'\b(law|laws)\b'),
    ];

    final legalContextSignals = <RegExp>[
      RegExp(r'\b(regulatory|compliance|non compliance|breach|criminal|penalty|sanction)\b'),
      RegExp(r'\b(financial transaction\w*|record discrepanc\w*|privacy|confidential)\b'),
    ];

    final hrStrongSignals = <RegExp>[
      RegExp(r'\b(harass|bully|discriminat|retaliat)\b'),
      RegExp(r'\b(attendance|leave|benefit|payroll|salary|wage|compensation)\b'),
      RegExp(r'\b(performance|manager|supervisor)\b'),
      RegExp(r'\b(team conflict|workload|work conditions|workplace culture|employee relations)\b'),
      RegExp(r'\b(hiring|termination|promotion|demotion)\b'),
    ];

    final hrContextSignals = <RegExp>[
      RegExp(r'\b(hr policy|policy clarification|interpersonal|communication issue)\b'),
      RegExp(r'\b(scheduling|shift|pto|vacation|overtime)\b'),
    ];

    var legalScore = 0;
    var hrScore = 0;

    for (final signal in legalStrongSignals) {
      if (signal.hasMatch(text)) {
        legalScore += 3;
      }
    }

    for (final signal in legalContextSignals) {
      if (signal.hasMatch(text)) {
        legalScore += 1;
      }
    }

    for (final signal in hrStrongSignals) {
      if (signal.hasMatch(text)) {
        hrScore += 3;
      }
    }

    for (final signal in hrContextSignals) {
      if (signal.hasMatch(text)) {
        hrScore += 1;
      }
    }

    return (hrScore: hrScore, legalScore: legalScore);
  }

  static ComplaintDepartment _inferDepartmentFromScores({
    required int hrScore,
    required int legalScore,
  }) {
    if (legalScore > hrScore) return ComplaintDepartment.legal;
    return ComplaintDepartment.hr;
  }

  static String? _normalizeCategory(String raw) {
    final normalized = _normalizeTextToken(raw);
    if (normalized.isEmpty) return null;

    if (normalized.contains('harass')) return 'Harassment';
    if (normalized.contains('discriminat')) return 'Discrimination';
    if (normalized.contains('pay') ||
        normalized.contains('salary') ||
        normalized.contains('wage') ||
        normalized.contains('compensation')) {
      return 'Pay Dispute';
    }
    if (normalized.contains('safety') ||
        normalized.contains('unsafe') ||
        normalized.contains('hazard')) {
      return 'Workplace Safety';
    }
    if (normalized.contains('policy')) return 'Policy Violation';
    if (normalized.contains('performance')) return 'Performance Issue';
    if (normalized.contains('benefit')) return 'Benefits';
    if (normalized.contains('retaliat')) return 'Retaliation';
    if (normalized.contains('misconduct') ||
        normalized.contains('fraud') ||
        normalized.contains('theft') ||
        normalized.contains('corruption') ||
        normalized.contains('bribery')) {
      return 'Misconduct';
    }

    return null;
  }

  static String _inferCategoryFromComplaint({
    required String subject,
    required String description,
  }) {
    final text = _normalizeTextToken('$subject $description');

    if (text.contains('harass')) return 'Harassment';
    if (text.contains('discriminat')) return 'Discrimination';
    if (text.contains('pay') || text.contains('salary') || text.contains('wage')) {
      return 'Pay Dispute';
    }
    if (text.contains('safety') || text.contains('unsafe') || text.contains('hazard')) {
      return 'Workplace Safety';
    }
    if (text.contains('performance')) return 'Performance Issue';
    if (text.contains('benefit')) return 'Benefits';
    if (text.contains('retaliat')) return 'Retaliation';
    if (text.contains('fraud') ||
        text.contains('theft') ||
        text.contains('corruption') ||
        text.contains('bribery') ||
        text.contains('misconduct')) {
      return 'Misconduct';
    }

    return 'Policy Violation';
  }

  static String? _normalizeUrgency(String raw) {
    final normalized = _normalizeTextToken(raw);
    if (normalized.isEmpty) return null;

    if (normalized.contains('critical') || normalized.contains('immediate')) {
      return 'Critical';
    }
    if (normalized.contains('high') || normalized.contains('urgent')) {
      return 'High';
    }
    if (normalized.contains('medium') || normalized.contains('moderate')) {
      return 'Medium';
    }
    if (normalized.contains('low') || normalized.contains('minor') || normalized.contains('routine')) {
      return 'Low';
    }

    return null;
  }

  static String _inferUrgencyFromComplaint({
    required String subject,
    required String description,
  }) {
    final text = _normalizeTextToken('$subject $description');

    if (text.contains('violence') ||
        text.contains('assault') ||
        text.contains('threat') ||
        text.contains('data breach') ||
        text.contains('immediate danger')) {
      return 'Critical';
    }

    if (text.contains('harass') ||
        text.contains('fraud') ||
        text.contains('retaliat') ||
        text.contains('unsafe') ||
        text.contains('hazard')) {
      return 'High';
    }

    if (text.contains('pay') ||
        text.contains('salary') ||
        text.contains('policy') ||
        text.contains('performance') ||
        text.contains('benefit')) {
      return 'Medium';
    }

    return 'Low';
  }

  static String _summarizeFallback(
    String modelText,
    String category,
  ) {
    final clean = _stripCodeFences(modelText);
    if (clean.isNotEmpty) {
      final maxLen = clean.length > 220 ? 220 : clean.length;
      return clean.substring(0, maxLen).trim();
    }
    return 'Complaint categorized as $category.';
  }

  /// Classifies a complaint into a department based on its subject and description.
  /// Returns [ComplaintDepartment.hr] or [ComplaintDepartment.legal].
  static Future<ComplaintDepartment> classifyComplaint({
    required String subject,
    required String description,
  }) async {
    if (_apiKey.isEmpty) {
      throw 'Gemini API key is not configured. Please add it to .env file.';
    }

    final signalScores = _scoreDepartmentSignals(
      subject: subject,
      description: description,
    );

    final scoreDelta = (signalScores.legalScore - signalScores.hrScore).abs();

    // If one side is overwhelmingly stronger, skip model ambiguity.
    if (scoreDelta >= 6) {
      return _inferDepartmentFromScores(
        hrScore: signalScores.hrScore,
        legalScore: signalScores.legalScore,
      );
    }

    final prompt = '''
You are a neutral enterprise complaint router. Choose exactly one department: "hr" or "legal".

Decision policy:
- Choose "hr" for people-management issues and workplace operations (harassment, discrimination, performance, attendance, benefits, workload, manager conduct, team conflict) when legal/regulatory violations are not the core allegation.
- Choose "legal" for allegations that require legal/compliance review (fraud, corruption, bribery, contract disputes, privacy/data breaches, regulatory non-compliance, intellectual property theft, legal liability, or requested legal action).
- If both dimensions appear, choose the department that should lead first response based on primary risk in the complaint.
- Do not default to either class.

Complaint Subject: $subject
Complaint Description: $description

Return strict JSON only with no extra text:
{"department":"hr", "confidence":"<high|medium|low>"}
or
{"department":"legal", "confidence":"<high|medium|low>"}
''';

    final url = _buildUri();

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0,
          'maxOutputTokens': 64,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw 'Failed to classify complaint. Status: ${response.statusCode}';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractModelText(data);
    final parsed = _extractJsonObject(text);

    final departmentSource =
        (parsed?['department'] as String?) ??
        _extractLabeledValue(text, 'department') ??
        text;

    final confidenceSource =
        (parsed?['confidence'] as String?) ??
        _extractLabeledValue(text, 'confidence') ??
        'medium';

    final normalizedDepartment = _normalizeDepartment(departmentSource);
    final modelConfidence = _normalizeConfidenceScore(confidenceSource);
    if (normalizedDepartment == null) {
      return _inferDepartmentFromScores(
        hrScore: signalScores.hrScore,
        legalScore: signalScores.legalScore,
      );
    }

    final modelDepartment = normalizedDepartment == 'legal'
        ? ComplaintDepartment.legal
        : ComplaintDepartment.hr;

    final legalAdvantage = signalScores.legalScore - signalScores.hrScore;
    final hrAdvantage = signalScores.hrScore - signalScores.legalScore;

    if (modelDepartment == ComplaintDepartment.hr &&
        legalAdvantage >= 3 &&
        modelConfidence < 3) {
      return ComplaintDepartment.legal;
    }

    if (modelDepartment == ComplaintDepartment.legal &&
        hrAdvantage >= 3 &&
        modelConfidence < 3) {
      return ComplaintDepartment.hr;
    }

    return modelDepartment;
  }

  /// Assesses the urgency of a complaint using Gemini AI.
  ///
  /// Returns a record with:
  /// - `urgency` — one of: Critical, High, Medium, Low.
  /// - `reason`  — a 1-2 sentence explanation of the urgency rating.
  static Future<({String urgency, String reason})> assessUrgency({
    required String subject,
    required String description,
  }) async {
    if (_apiKey.isEmpty) {
      throw 'Gemini API key is not configured. Please add it to .env file.';
    }

    final prompt = '''
You are an expert workplace complaint triage analyst. Assess the URGENCY of the following complaint.

Urgency levels (pick exactly one):
- "Critical" — Immediate danger, active threats, violence, ongoing sexual assault, imminent legal liability, data breach in progress, or any situation requiring same-day intervention.
- "High" — Serious harm already occurred, credible harassment/discrimination, significant financial fraud, safety hazard, retaliation against whistleblower, or situations needing action within 24-48 hours.
- "Medium" — Ongoing workplace issue causing distress but no immediate danger, pay disputes, policy violations, performance conflicts, or situations that should be addressed within 1-2 weeks.
- "Low" — General feedback, minor policy clarifications, benefits questions, non-urgent process complaints, or matters that can be scheduled for regular review.

Complaint Subject: $subject
Complaint Description: $description

Respond in this EXACT JSON format with no extra text:
{"urgency": "<Critical|High|Medium|Low>", "reason": "<1-2 sentence explanation>"}
''';

    final url = _buildUri();

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 256,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw 'Failed to assess urgency. Status: ${response.statusCode}';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractModelText(data);
    final parsed = _extractJsonObject(text);

    final urgencySource =
        (parsed?['urgency'] as String?) ??
        _extractLabeledValue(text, 'urgency') ??
        _extractLabeledValue(text, 'severity') ??
        text;

    final urgency = _normalizeUrgency(urgencySource) ??
        _inferUrgencyFromComplaint(subject: subject, description: description);

    final reasonSource =
        (parsed?['reason'] as String?) ?? _extractLabeledValue(text, 'reason');
    final reason = (reasonSource != null && reasonSource.trim().isNotEmpty)
        ? reasonSource.trim()
        : 'Urgency assessed as $urgency based on complaint details.';

    return (urgency: urgency, reason: reason);
  }

  /// Classifies a complaint into a category and provides
  /// a brief AI summary to help HR/Legal organize and prioritize cases.
  ///
  /// Returns a record with:
  /// - `category` — one of: Harassment, Discrimination, Pay Dispute,
  ///   Workplace Safety, Policy Violation, Performance Issue, Benefits,
  ///   Misconduct, Retaliation, or Other.
  /// - `summary` — a 1-2 sentence summary with recommended priority.
  static Future<({String category, String summary})> classifyComplaintCategory({
    required String subject,
    required String description,
  }) async {
    if (_apiKey.isEmpty) {
      throw 'Gemini API key is not configured. Please add it to .env file.';
    }

    final prompt = '''
You are an expert HR complaint analyst. Analyze the following complaint and provide:

1. CATEGORY: Classify into exactly ONE of these categories:
   - Harassment
   - Discrimination
   - Pay Dispute
   - Workplace Safety
   - Policy Violation
   - Performance Issue
   - Benefits
   - Misconduct
   - Retaliation

   IMPORTANT: Always pick the single best matching category from the list above. Never return "Other" — if the complaint is ambiguous, choose whichever category best describes the dominant theme.

2. SUMMARY: Write a brief 1-2 sentence professional summary of the complaint, highlighting the key issue and suggesting a priority level (Low, Medium, High, or Critical).

Complaint Subject: $subject
Complaint Description: $description

Respond in this EXACT JSON format with no extra text:
{"category": "<category>", "summary": "<summary>"}
''';

    final url = _buildUri();

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 256,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw 'Failed to classify complaint. Status: ${response.statusCode}';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractModelText(data);
    final parsed = _extractJsonObject(text);

    final categorySource =
        (parsed?['category'] as String?) ??
        _extractLabeledValue(text, 'category') ??
        text;

    final category = _normalizeCategory(categorySource) ??
        _inferCategoryFromComplaint(subject: subject, description: description);

    final summarySource =
        (parsed?['summary'] as String?) ?? _extractLabeledValue(text, 'summary');
    final summary = (summarySource != null && summarySource.trim().isNotEmpty)
        ? summarySource.trim()
        : _summarizeFallback(text, category);

    return (category: category, summary: summary);
  }
}
