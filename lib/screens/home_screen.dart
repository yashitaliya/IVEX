import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../services/auth_controller.dart';
import '../services/appwrite_service.dart';
import '../models/analysis_result.dart';
import 'profile_screen.dart';
import 'result_screen.dart';

/// IVEX Home Screen
/// Clean design with Electric Cyan accent on Deep Charcoal background
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final AppwriteService _appwrite = AppwriteService();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  String _uploadStatus = '';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'STUDIO',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _isUploading ? _buildLoadingState() : _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    final auth = context.watch<AuthController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hello, ${auth.displayName.isEmpty ? 'IVEX User' : auth.displayName}',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Your premium studio is ready.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Ready for your signature look?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a clear selfie to begin the analysis.',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 15,
            ),
          ),
          const Spacer(),
          _buildScanButton(),
          const SizedBox(height: 28),
          const Spacer(flex: 2),
          _buildRecentResults(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _pickAndUploadImage,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white : Colors.black,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                color: isDark ? Colors.black : Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'SCAN',
                style: GoogleFonts.inter(
                  color: isDark ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 32),
            Text(
              _uploadStatus.toUpperCase(),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentResults() {
    return FutureBuilder(
      future: _appwrite.getResults(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final results = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PAST ANALYSES',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: results.length.clamp(0, 5),
                itemBuilder: (context, index) {
                  final result = AnalysisResult.fromDocument(results[index].data);
                  return _buildResultThumbnail(result);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultThumbnail(AnalysisResult result) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              fileId: result.originalFileId,
              existingResult: result,
            ),
          ),
        );
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: (result.generatedImageUrl.isNotEmpty &&
                  _looksLikeImageUrl(result.generatedImageUrl))
              ? CachedNetworkImage(
                  imageUrl: result.generatedImageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1))),
                  errorWidget: (context, url, error) => const Icon(Icons.face, size: 20),
                )
              : const Icon(Icons.face, size: 20),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildSourcePicker(),
    );

    if (source == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatus = 'Preparing your image...';
      });

      final bytes = await File(pickedFile.path).readAsBytes();
      final fileName = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() {
        _uploadStatus = 'Uploading to IVEX cloud...';
      });

      final fileId = await _appwrite.uploadImage(bytes.toList(), fileName);

      setState(() {
        _uploadStatus = 'AI is analyzing your geometry...';
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ResultScreen(fileId: fileId)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  Widget _buildSourcePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSourceOption(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              _buildSourceOption(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
