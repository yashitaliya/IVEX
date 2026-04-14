import 'dart:convert';

/// Model class for hairstyle analysis results.
///
/// Supports both the new structured JSON format (from MediaPipe pipeline)
/// and legacy plain-text format for backward compatibility with old results.
class AnalysisResult {
  final String id;
  final String originalFileId;
  final String status;
  final String faceShape;
  final String adviceText;
  final String generatedImageUrl;
  final DateTime createdAt;

  // ── New structured fields (from MediaPipe pipeline) ──
  final double? confidence;
  final Map<String, double>? measurements;
  final List<String>? recommendedStyles;
  final List<String>? avoidStyles;
  final String? stylingTip;

  AnalysisResult({
    required this.id,
    required this.originalFileId,
    required this.status,
    required this.faceShape,
    required this.adviceText,
    required this.generatedImageUrl,
    required this.createdAt,
    this.confidence,
    this.measurements,
    this.recommendedStyles,
    this.avoidStyles,
    this.stylingTip,
  });

  /// Create from Appwrite document.
  /// Handles both structured JSON and legacy plain-text in advice_text.
  factory AnalysisResult.fromDocument(Map<String, dynamic> doc) {
    final rawAdvice = doc['advice_text'] ?? '';

    // Try to parse advice_text as structured JSON
    double? confidence;
    Map<String, double>? measurements;
    List<String>? recommendedStyles;
    List<String>? avoidStyles;
    String? stylingTip;
    String adviceText = rawAdvice;

    try {
      final parsed = jsonDecode(rawAdvice);
      if (parsed is Map<String, dynamic>) {
        // ── Structured format detected ──
        confidence = (parsed['confidence'] as num?)?.toDouble();

        // Parse measurements
        if (parsed['measurements'] is Map) {
          final m = parsed['measurements'] as Map<String, dynamic>;
          measurements = {};
          m.forEach((key, value) {
            if (value is num) {
              measurements![key] = value.toDouble();
            }
          });
        }

        // Parse recommendations
        if (parsed['recommendations'] is Map) {
          final recs = parsed['recommendations'] as Map<String, dynamic>;
          if (recs['recommended'] is List) {
            recommendedStyles =
                (recs['recommended'] as List).cast<String>().toList();
          }
          if (recs['avoid'] is List) {
            avoidStyles = (recs['avoid'] as List).cast<String>().toList();
          }
          stylingTip = recs['tip'] as String?;
        }

        // Use the human-readable advice text
        adviceText = parsed['advice'] as String? ?? rawAdvice;
      }
    } catch (_) {
      // Not JSON — treat as legacy plain-text advice
      adviceText = rawAdvice;
    }

    return AnalysisResult(
      id: doc['\$id'] ?? '',
      originalFileId: doc['original_file_id'] ?? '',
      status: doc['status'] ?? 'pending',
      faceShape: doc['face_shape'] ?? '',
      adviceText: adviceText,
      generatedImageUrl: doc['generated_image_url'] ?? '',
      createdAt: doc['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(doc['created_at'])
          : DateTime.now(),
      confidence: confidence,
      measurements: measurements,
      recommendedStyles: recommendedStyles,
      avoidStyles: avoidStyles,
      stylingTip: stylingTip,
    );
  }

  /// Whether this result has structured data from the MediaPipe pipeline
  bool get hasStructuredData => confidence != null && measurements != null;

  /// Confidence as a percentage string (e.g., "87%")
  String get confidencePercent =>
      confidence != null ? '${(confidence! * 100).round()}%' : '';

  /// Check if analysis is still processing
  bool get isProcessing => status == 'processing' || status == 'pending';

  /// Check if analysis completed successfully
  bool get isCompleted => status == 'completed';

  /// Check if analysis had an error
  bool get hasError => status == 'error';

  /// Get display-friendly face shape
  String get displayFaceShape => faceShape.toUpperCase();

  @override
  String toString() {
    return 'AnalysisResult(id: $id, status: $status, faceShape: $faceShape, '
        'confidence: $confidence)';
  }
}
