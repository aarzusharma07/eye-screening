import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'quality_check_screen.dart';

class ImageUploadScreen extends StatefulWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;
  final String? village;
  final String? phone;
  final bool hasHypertension;
  final bool hasPrevEyeIssues;

  const ImageUploadScreen({
    super.key,
    required this.visitId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.diabetesDuration,
    this.village,
    this.phone,
    this.hasHypertension = false,
    this.hasPrevEyeIssues = false,
  });

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen>
    with SingleTickerProviderStateMixin {
  XFile? _leftEyeFile;
  XFile? _rightEyeFile;
  Uint8List? _leftEyeBytes;
  Uint8List? _rightEyeBytes;
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _errorMsg;
  final _captureNotesController = TextEditingController();

  // Pre-capture checklist
  bool _lensAttached = false;
  bool _goodLighting = false;
  bool _patientCooperative = false;
  bool _checklistExpanded = true;

  late TabController _tabController;

  bool get _checklistComplete => _lensAttached && _goodLighting && _patientCooperative;

  Future<void> _loadSampleImages() async {
    try {
      final byteData = await rootBundle.load('assets/images/heatmap_sample.jpg');
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _leftEyeBytes = bytes;
        _rightEyeBytes = bytes;
        _leftEyeFile = XFile.fromData(bytes, name: 'left_sample.jpg', mimeType: 'image/jpeg');
        _rightEyeFile = XFile.fromData(bytes, name: 'right_sample.jpg', mimeType: 'image/jpeg');
        _lensAttached = true;
        _goodLighting = true;
        _patientCooperative = true;
        _errorMsg = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loaded sample retinal images for both eyes!'),
          backgroundColor: Color(0xFF1565C0),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error loading sample images: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _captureNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String eye, ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        if (eye == 'left') {
          _leftEyeFile = pickedFile;
          _leftEyeBytes = bytes;
        } else {
          _rightEyeFile = pickedFile;
          _rightEyeBytes = bytes;
        }
      });
    }
  }

  void _showQualityHint(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Capture Guidance', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GuidanceTip(icon: Icons.center_focus_strong, text: 'Center the pupil in the frame'),
            _GuidanceTip(icon: Icons.straighten, text: 'Maintain 2–3 cm distance from the eye'),
            _GuidanceTip(icon: Icons.wb_sunny, text: 'Ensure even, diffuse lighting — avoid shadows'),
            _GuidanceTip(icon: Icons.stay_current_portrait, text: 'Hold device steady — no hand motion'),
            _GuidanceTip(icon: Icons.remove_red_eye, text: 'Ask patient to look at a fixed point ahead'),
            _GuidanceTip(icon: Icons.circle, text: 'The optic disc should be visible in the image'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    if (_leftEyeFile == null || _rightEyeFile == null) {
      setState(() => _errorMsg = 'Please capture/select both left and right eye images.');
      return;
    }

    setState(() {
      _uploading = true;
      _errorMsg = null;
    });

    // Update visit with capture notes
    final captureNotes = _captureNotesController.text.trim().isEmpty
        ? null
        : _captureNotesController.text.trim();
    if (captureNotes != null) {
      await ApiService.createVisit(
        0,
        captureNotes: captureNotes,
      );
    }

    final result = await ApiService.uploadRetinalImages(
      visitId: widget.visitId,
      leftEyeFile: _leftEyeFile!,
      rightEyeFile: _rightEyeFile!,
    );

    setState(() => _uploading = false);

    if (result == null) {
      setState(() => _errorMsg = 'Upload failed. Check that both files are valid eye images and try again.');
      return;
    }

    // Extract quality info
    final images = result['images'] as List<dynamic>;
    Map<String, dynamic>? leftQuality;
    Map<String, dynamic>? rightQuality;

    for (final img in images) {
      if ((img['eye'] as String).toLowerCase() == 'left') {
        leftQuality = img as Map<String, dynamic>;
      } else {
        rightQuality = img as Map<String, dynamic>;
      }
    }

    // Check if any eye needs recapture
    final leftPoor = leftQuality?['quality'] == 'Poor';
    final rightPoor = rightQuality?['quality'] == 'Poor';

    double safeScore(Map<String, dynamic>? m, String key1, String key2) {
      if (m == null) return 1.0;
      final v = m[key1] ?? m[key2];
      if (v is num) return v.toDouble();
      return 1.0;
    }

    if ((leftPoor || rightPoor) && mounted) {
      // Show recapture dialog
      final recapture = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Image Quality Warning', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'One or more images have poor quality:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (leftPoor)
                _QualityRow(
                  eye: 'Left Eye',
                  quality: leftQuality?['quality'] ?? 'Poor',
                  focus: safeScore(leftQuality, 'focus_score', 'focus'),
                  lighting: safeScore(leftQuality, 'lighting_score', 'lighting'),
                  clarity: safeScore(leftQuality, 'clarity_score', 'clarity'),
                ),
              if (rightPoor)
                _QualityRow(
                  eye: 'Right Eye',
                  quality: rightQuality?['quality'] ?? 'Poor',
                  focus: safeScore(rightQuality, 'focus_score', 'focus'),
                  lighting: safeScore(rightQuality, 'lighting_score', 'lighting'),
                  clarity: safeScore(rightQuality, 'clarity_score', 'clarity'),
                ),
              const SizedBox(height: 12),
              const Text(
                'Poor quality images may reduce AI accuracy. Do you want to recapture?',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue Anyway'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Recapture'),
            ),
          ],
        ),
      );

      if (recapture == true) return; // Stay on this screen for recapture
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QualityCheckScreen(
            visitId: widget.visitId,
            patientName: widget.patientName,
            patientAge: widget.patientAge,
            patientGender: widget.patientGender,
            diabetesDuration: widget.diabetesDuration,
            leftQuality: leftQuality,
            rightQuality: rightQuality,
          ),
        ),
      );
    }
  }

  Widget _buildEyePanel(String eye) {
    final isLeft = eye == 'left';
    final fileBytes = isLeft ? _leftEyeBytes : _rightEyeBytes;
    final eyeLabel = isLeft ? 'Left Eye (OS)' : 'Right Eye (OD)';
    final eyeColor = isLeft ? const Color(0xFF1565C0) : const Color(0xFF00695C);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Alignment guidance banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: eyeColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: eyeColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: eyeColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLeft
                        ? 'Left eye: Patient looks slightly right. Lens at nasal side.'
                        : 'Right eye: Patient looks slightly left. Lens at nasal side.',
                    style: TextStyle(fontSize: 12, color: eyeColor),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showQualityHint(context),
                  child: Text('Guide', style: TextStyle(color: eyeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Image preview
          GestureDetector(
            onTap: () => _pickImage(eye, ImageSource.gallery),
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: fileBytes != null ? eyeColor : Colors.grey.shade300,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
                color: fileBytes != null ? null : Colors.grey.shade50,
              ),
              child: fileBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_red_eye, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(
                          'Tap to select or use camera below',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (fileBytes != null)
                            Image.memory(fileBytes, fit: BoxFit.cover)
                          else
                            const SizedBox.shrink(),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text('Captured', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(eye, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(backgroundColor: eyeColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(eye, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: eyeColor),
                    foregroundColor: eyeColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Image Capture — ${widget.patientName}'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Capture Guide',
            onPressed: () => _showQualityHint(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Pre-capture checklist ──────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            decoration: BoxDecoration(
              color: _checklistComplete
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _checklistComplete ? Colors.green : Colors.orange,
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _checklistExpanded = !_checklistExpanded),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _checklistComplete ? Icons.check_circle : Icons.checklist,
                          color: _checklistComplete ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _checklistComplete
                                ? 'Pre-capture checklist complete ✓'
                                : 'Complete pre-capture checklist',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _checklistComplete ? Colors.green : Colors.orange.shade800,
                            ),
                          ),
                        ),
                        Icon(
                          _checklistExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_checklistExpanded) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                    child: Column(
                      children: [
                        _ChecklistTile(
                          label: 'Fundus lens / adapter attached to phone',
                          value: _lensAttached,
                          onChanged: (v) => setState(() => _lensAttached = v!),
                        ),
                        _ChecklistTile(
                          label: 'Lighting adequate (no harsh shadows)',
                          value: _goodLighting,
                          onChanged: (v) => setState(() => _goodLighting = v!),
                        ),
                        _ChecklistTile(
                          label: 'Patient is cooperative and positioned',
                          value: _patientCooperative,
                          onChanged: (v) => setState(() => _patientCooperative = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Quick Demo Button ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _loadSampleImages,
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF1565C0), size: 18),
              label: const Text(
                '⚡ Load Sample Retinal Images (Quick Demo)',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                side: BorderSide(color: Colors.blue.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ),

          // ── Tab bar (Left / Right eye) ─────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_leftEyeFile != null ? Icons.check_circle : Icons.remove_red_eye, size: 16),
                      const SizedBox(width: 6),
                      const Text('Left Eye (OS)'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_rightEyeFile != null ? Icons.check_circle : Icons.remove_red_eye, size: 16),
                      const SizedBox(width: 6),
                      const Text('Right Eye (OD)'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab content ────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEyePanel('left'),
                _buildEyePanel('right'),
              ],
            ),
          ),

          // ── Capture Notes ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _captureNotesController,
              decoration: InputDecoration(
                hintText: 'Optional nurse notes (e.g. poor cooperation, low light, media opacity)...',
                prefixIcon: const Icon(Icons.notes, size: 18),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              maxLines: 2,
            ),
          ),

          // ── Error & Upload button ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),

                // Status row
                Row(
                  children: [
                    _EyeStatusDot(label: 'L', captured: _leftEyeFile != null),
                    const SizedBox(width: 6),
                    _EyeStatusDot(label: 'R', captured: _rightEyeFile != null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _uploading ? null : _upload,
                          icon: _uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload),
                          label: Text(
                            _uploading
                                ? 'Uploading & Checking Quality...'
                                : 'Upload & Check Quality',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Step indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: Color(0xFF1565C0),
                  child: Text('2', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8),
                Text(
                  'Step 2 of 5 — Retinal Image Capture',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _ChecklistTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _ChecklistTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        activeColor: const Color(0xFF1565C0),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }
}

class _EyeStatusDot extends StatelessWidget {
  final String label;
  final bool captured;
  const _EyeStatusDot({required this.label, required this.captured});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: captured ? Colors.green : Colors.grey.shade300,
          child: Text(
            label,
            style: TextStyle(
              color: captured ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          captured ? '✓' : '—',
          style: TextStyle(fontSize: 10, color: captured ? Colors.green : Colors.grey),
        ),
      ],
    );
  }
}

class _GuidanceTip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuidanceTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1565C0)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  final String eye, quality;
  final double focus, lighting, clarity;
  const _QualityRow({
    required this.eye,
    required this.quality,
    required this.focus,
    required this.lighting,
    required this.clarity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eye, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                _ScorePill('Focus', focus),
                const SizedBox(width: 6),
                _ScorePill('Light', lighting),
                const SizedBox(width: 6),
                _ScorePill('Clarity', clarity),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final double score;
  const _ScorePill(this.label, this.score);

  @override
  Widget build(BuildContext context) {
    final good = score >= 0.6;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: good ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${(score * 100).toInt()}%',
        style: TextStyle(
          fontSize: 11,
          color: good ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}