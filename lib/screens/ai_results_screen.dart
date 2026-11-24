import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'heatmap_screen.dart';
import 'referral_report_screen.dart';

class AIResultsScreen extends StatefulWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;

  const AIResultsScreen({
    super.key,
    required this.visitId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.diabetesDuration,
  });

  @override
  State<AIResultsScreen> createState() => _AIResultsScreenState();
}

class _AIResultsScreenState extends State<AIResultsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _errorMsg;
  Map<String, dynamic>? _result;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _runAnalysis();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final result = await ApiService.runAIPrediction(widget.visitId);
    if (mounted) {
      if (result == null) {
        setState(() {
          _loading = false;
          _errorMsg = 'AI analysis failed. Please try again.';
        });
      } else {
        setState(() {
          _loading = false;
          _result = result;
        });
        _animController.forward();
      }
    }
  }

  // Triage colour/icon config
  Map<String, dynamic> _tierConfig(String? tier) {
    switch (tier) {
      case 'Urgent Referral':
        return {
          'color': const Color(0xFFD32F2F),
          'bg': const Color(0xFFFFEBEE),
          'icon': Icons.emergency,
          'label': '🔴  URGENT REFERRAL',
          'subtitle': 'Refer to ophthalmologist within 24–48 hrs',
        };
      case 'Refer':
        return {
          'color': const Color(0xFFE65100),
          'bg': const Color(0xFFFFF3E0),
          'icon': Icons.send,
          'label': '🟠  REFERRAL RECOMMENDED',
          'subtitle': 'Refer to district eye clinic within 1–2 weeks',
        };
      case 'Monitor':
        return {
          'color': const Color(0xFFF9A825),
          'bg': const Color(0xFFFFFDE7),
          'icon': Icons.schedule,
          'label': '🟡  MONITOR — FOLLOW-UP IN 6 MONTHS',
          'subtitle': 'Borderline findings. Schedule follow-up',
        };
      default: // Reassure
        return {
          'color': const Color(0xFF2E7D32),
          'bg': const Color(0xFFE8F5E9),
          'icon': Icons.check_circle,
          'label': '🟢  REASSURE — NO REFERRAL NEEDED',
          'subtitle': 'No significant glaucoma indicators detected',
        };
    }
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'High': return const Color(0xFFD32F2F);
      case 'Medium': return const Color(0xFFE65100);
      default: return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('AI Screening Results'),
        centerTitle: true,
      ),
      body: _loading ? _buildLoading() : _errorMsg != null ? _buildError() : _buildResults(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Running AI Analysis...',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 8),
          const Text('Processing retinal images with EfficientNet-B3',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 6),
          const Text('Generating Grad-CAM heatmaps...',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(_errorMsg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _runAnalysis,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final predictions = _result!['predictions'] as List<dynamic>;
    final referralTier = _result!['referral_tier'] as String?;
    final referralReason = _result!['referral_reason'] as String? ?? '';
    final advisoryNote = _result!['advisory_note'] as String? ?? '';
    final referralNeeded = _result!['referral_needed'] as bool? ?? false;

    final tierCfg = _tierConfig(referralTier);
    final tierColor = tierCfg['color'] as Color;
    final tierBg = tierCfg['bg'] as Color;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Triage Banner ─────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: tierBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: tierColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Icon(tierCfg['icon'] as IconData, color: tierColor, size: 52),
                  const SizedBox(height: 10),
                  Text(
                    tierCfg['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tierColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tierCfg['subtitle'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tierColor.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Per-eye Prediction Cards ───────────────────────────
            const Text(
              'Per-Eye Findings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 10),

            ...predictions.map((p) {
              final eye = p['eye'] as String? ?? 'Unknown';
              final quality = p['quality'] as String? ?? 'Good';
              final gradability = p['gradability'] as String? ?? 'Gradable';
              
              // Glaucoma data
              final gCls = (p['glaucoma_class'] ?? p['class'] ?? 'normal') as String;
              final gProb = ((p['glaucoma_probability'] ?? p['probability'] ?? 0.0) as num).toDouble();
              final gRisk = (p['glaucoma_risk'] ?? p['risk_category'] ?? 'Low') as String;
              final isGlaucoma = gCls.toLowerCase() == 'glaucoma';
              final gColor = _riskColor(gRisk);

              // DR data
              final drCls = (p['dr_class'] ?? 'No DR') as String;
              final drProb = ((p['dr_probability'] ?? 0.0) as num).toDouble();
              final drRisk = (p['dr_risk'] ?? 'Low') as String;
              final isDR = drCls != 'No DR';
              final drColor = _riskColor(drRisk);

              // Highest eye risk color
              final eyeRiskColor = (gRisk == 'High' || drRisk == 'High')
                  ? Colors.red
                  : (gRisk == 'Medium' || drRisk == 'Medium')
                      ? Colors.orange
                      : Colors.green;

              final qualColor = quality == 'Good' ? Colors.green : Colors.orange;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: eyeRiskColor.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eye header
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFF1565C0),
                            radius: 18,
                            child: Text(
                              eye[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$eye Eye Retinal Scan',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: eyeRiskColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: eyeRiskColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              (gRisk == 'High' || drRisk == 'High')
                                  ? 'High Risk'
                                  : (gRisk == 'Medium' || drRisk == 'Medium')
                                      ? 'Medium Risk'
                                      : 'Low Risk',
                              style: TextStyle(
                                color: eyeRiskColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 1. GLAUCOMA ASSESSMENT BOX
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBDEFB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('🩺 ', style: TextStyle(fontSize: 14)),
                                    const Text('Glaucoma:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      gCls.toUpperCase(),
                                      style: TextStyle(
                                        color: isGlaucoma ? Colors.red : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(gProb * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: gColor, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: gProb.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(gColor),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 2. DIABETIC RETINOPATHY ASSESSMENT BOX
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE0B2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('🩸 ', style: TextStyle(fontSize: 14)),
                                    const Text('Diabetic Retinopathy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      drCls.toUpperCase(),
                                      style: TextStyle(
                                        color: isDR ? Colors.deepOrange.shade800 : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(drProb * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: drColor, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: drProb.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(drColor),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quality + Gradability badges
                      Row(
                        children: [
                          _InfoChip(
                            label: 'Quality: $quality',
                            color: qualColor,
                            icon: quality == 'Good' ? Icons.check : Icons.warning_amber,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            label: gradability,
                            color: gradability == 'Gradable' ? Colors.blue : Colors.orange,
                            icon: gradability == 'Gradable' ? Icons.visibility : Icons.visibility_off,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 6),

            // ── Advisory Note ──────────────────────────────────────
            if (advisoryNote.isNotEmpty) ...[
              const Text(
                'Clinical Advisory',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tierBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tierColor.withOpacity(0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_services, color: tierColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        advisoryNote,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Action Buttons ─────────────────────────────────────
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HeatmapScreen(
                            visitId: widget.visitId,
                            patientName: widget.patientName,
                            patientAge: widget.patientAge,
                            patientGender: widget.patientGender,
                            diabetesDuration: widget.diabetesDuration,
                            predictions: _result!['predictions'] as List<dynamic>,
                            referralNeeded: referralNeeded,
                            referralReason: referralReason,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.thermostat, size: 18),
                    label: const Text('Heatmap'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReferralReportScreen(
                            visitId: widget.visitId,
                            patientName: widget.patientName,
                            patientAge: widget.patientAge,
                            patientGender: widget.patientGender,
                            diabetesDuration: widget.diabetesDuration,
                            predictions: _result!['predictions'] as List<dynamic>,
                            referralNeeded: referralNeeded,
                            referralReason: referralReason,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Download Report'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _InfoChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}