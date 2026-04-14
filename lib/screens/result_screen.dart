import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:ui';
import '../services/appwrite_service.dart';
import '../models/analysis_result.dart';
import '../config/appwrite_config.dart';

class ResultScreen extends StatefulWidget {
  final String fileId;
  final AnalysisResult? existingResult;

  const ResultScreen({super.key, required this.fileId, this.existingResult});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final AppwriteService _appwrite = AppwriteService();

  AnalysisResult? _result;
  StreamSubscription? _subscription;
  bool _isWaiting = true;
  Timer? _pollTimer;

  bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('/storage/buckets/');
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingResult != null) {
      _result = widget.existingResult;
      _isWaiting = _result!.isProcessing;
    }
    _subscribeToResults();
    _startPolling();
  }

  void _subscribeToResults() {
    final subscription = _appwrite.subscribeToResults(widget.fileId);
    _subscription = subscription.stream.listen((event) {
      final payload = event.payload;
      if (payload['original_file_id'] == widget.fileId) {
        final result = AnalysisResult.fromDocument(payload);
        setState(() {
          _result = result;
          _isWaiting = result.isProcessing;
        });
        if (!result.isProcessing) _pollTimer?.cancel();
      }
    });
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final docs = await _appwrite.databases.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.resultsCollectionId,
          queries: [
            Query.equal('original_file_id', widget.fileId),
            Query.limit(1),
          ],
        );

        if (docs.documents.isNotEmpty) {
          final doc = docs.documents.first;
          final result = AnalysisResult.fromDocument(doc.data);
          setState(() {
            _result = result;
            _isWaiting = result.isProcessing;
          });
          if (!result.isProcessing) timer.cancel();
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: _isWaiting && _result == null
          ? _buildWaitingState()
          : _result != null
              ? _buildResultContent()
              : _buildWaitingState(),
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 32),
          Text(
            'ANALYZING GEOMETRY',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Detecting landmarks & measuring ratios',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent() {
    final result = _result!;
    if (result.hasError) return _buildErrorState(result.adviceText);
    if (result.isProcessing) return _buildWaitingState();
    final hasRenderableImage =
        result.generatedImageUrl.isNotEmpty && _looksLikeImageUrl(result.generatedImageUrl);

    return Stack(
      children: [
        Positioned.fill(
          child: hasRenderableImage
              ? CachedNetworkImage(
                  imageUrl: result.generatedImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.black),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.white70,
                      size: 42,
                    ),
                  ),
                )
              : Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white70,
                    size: 42,
                  ),
                ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.40,
          minChildSize: 0.30,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.90),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    children: [
                      // ── Drag handle ──
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Face Shape + Confidence ──
                      _buildShapeHeader(result),
                      const SizedBox(height: 24),

                      // ── Measurements (if available) ──
                      if (result.hasStructuredData) ...[
                        _buildMeasurementsCard(result),
                        const SizedBox(height: 24),
                      ],

                      // ── Recommended Styles ──
                      if (result.recommendedStyles != null &&
                          result.recommendedStyles!.isNotEmpty) ...[
                        _buildRecommendedStyles(result),
                        const SizedBox(height: 24),
                      ],

                      // ── Styling Tip ──
                      if (result.stylingTip != null) ...[
                        _buildStylingTip(result),
                        const SizedBox(height: 24),
                      ],

                      // ── Styles to Avoid ──
                      if (result.avoidStyles != null &&
                          result.avoidStyles!.isNotEmpty) ...[
                        _buildAvoidStyles(result),
                        const SizedBox(height: 24),
                      ],

                      // ── Full Advice Text (fallback for legacy) ──
                      if (!result.hasStructuredData && result.adviceText.isNotEmpty) ...[
                        _buildLegacyAdvice(result),
                        const SizedBox(height: 24),
                      ],

                      // ── New Session button ──
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('New Session'),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Face shape name + confidence badge
  Widget _buildShapeHeader(AnalysisResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALYSIS RESULT',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                result.displayFaceShape,
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
            if (result.confidence != null) ...[
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withOpacity(0.15),
                    ),
                  ),
                  child: Text(
                    result.confidencePercent,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Visual measurement bars
  Widget _buildMeasurementsCard(AnalysisResult result) {
    final m = result.measurements!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MEASUREMENTS',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 14),
        _buildMeasurementBar(
          'Width / Height',
          m['widthHeightRatio'] ?? 0,
          barColor,
        ),
        const SizedBox(height: 10),
        _buildMeasurementBar(
          'Jaw / Cheek',
          m['jawCheekRatio'] ?? 0,
          barColor,
        ),
        const SizedBox(height: 10),
        _buildMeasurementBar(
          'Forehead / Cheek',
          m['foreheadCheekRatio'] ?? 0,
          barColor,
        ),
        const SizedBox(height: 10),
        _buildMeasurementBar(
          'Jaw Softness',
          m['jawlineAngle'] ?? 0,
          barColor,
        ),
      ],
    );
  }

  Widget _buildMeasurementBar(String label, double value, Color barColor) {
    // Clamp value to 0-1 range for display
    final displayValue = value.clamp(0.0, 1.2);
    final barFraction = (displayValue / 1.2).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: barFraction,
            backgroundColor: barColor.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(barColor.withOpacity(0.25)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  /// Recommended hairstyle chips
  Widget _buildRecommendedStyles(AnalysisResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOMMENDED STYLES',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: result.recommendedStyles!.map((style) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              child: Text(
                style,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Styling tip card
  Widget _buildStylingTip(AnalysisResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRO TIP',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.stylingTip!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Styles to avoid (de-emphasized)
  Widget _buildAvoidStyles(AnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STYLES TO AVOID',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 10),
        ...result.avoidStyles!.map((style) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    style,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Legacy plain-text advice (backward compatibility)
  Widget _buildLegacyAdvice(AnalysisResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STYLING ADVICE',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          result.adviceText,
          style: GoogleFonts.inter(
            fontSize: 16,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 24),
            Text(
              'Oops.',
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              error.isNotEmpty ? error : 'Analysis failed. Try another photo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
