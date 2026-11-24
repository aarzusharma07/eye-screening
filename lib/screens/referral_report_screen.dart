import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReferralReportScreen extends StatefulWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;
  final List<dynamic> predictions;
  final bool referralNeeded;
  final String referralReason;

  const ReferralReportScreen({
    super.key,
    required this.visitId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.diabetesDuration,
    required this.predictions,
    required this.referralNeeded,
    required this.referralReason,
  });

  @override
  State<ReferralReportScreen> createState() => _ReferralReportScreenState();
}

class _ReferralReportScreenState extends State<ReferralReportScreen> {
  bool _generatingPdf = false;

  String _riskLabel() {
    bool hasHigh = widget.predictions.any((p) =>
        (p['risk_category'] as String? ?? '').toLowerCase() == 'high');
    bool hasMedium = widget.predictions.any((p) =>
        (p['risk_category'] as String? ?? '').toLowerCase() == 'medium');
    if (hasHigh) return 'High';
    if (hasMedium) return 'Medium';
    return 'Low';
  }

  Future<void> _downloadPdf() async {
    setState(() => _generatingPdf = true);
    final success = await ApiService.generateAndOpenReportPdf(widget.visitId);
    setState(() => _generatingPdf = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'PDF Report downloaded and opened successfully!'
                : 'Failed to generate PDF. Is the backend running?',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Referral Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.description, color: Colors.white, size: 80),
                  SizedBox(height: 15),
                  Text(
                    'Eye Screening Referral Report',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            _buildSection('Patient Information', {
              'Patient Name': widget.patientName,
              'Age': '${widget.patientAge} Years',
              'Gender': widget.patientGender,
              'Diabetes Duration':
                  '${widget.diabetesDuration.toStringAsFixed(1)} Years',
            }),
            const SizedBox(height: 20),

            _buildSection('AI Screening Results', {
              for (final p in widget.predictions)
                '${p['eye']} Eye — ${(p['class'] as String).toUpperCase()}':
                    '${((p['probability'] as num).toDouble() * 100).toStringAsFixed(1)}% (${p['risk_category']} Risk)',
              'Overall Risk Level': _riskLabel(),
              'Confidence':
                  '${((widget.predictions.isNotEmpty ? (widget.predictions.first['confidence'] as num).toDouble() : 0) * 100).toStringAsFixed(0)}%',
            }),
            const SizedBox(height: 20),

            // Referral status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.referralNeeded
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.referralNeeded ? Colors.red : Colors.green,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.referralNeeded ? Icons.warning : Icons.check_circle,
                        color: widget.referralNeeded ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.referralNeeded
                            ? 'Urgent Referral Required'
                            : 'No Referral Required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: widget.referralNeeded ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.referralReason.isNotEmpty
                        ? widget.referralReason
                        : widget.referralNeeded
                            ? 'Glaucoma indicators detected. Refer to ophthalmologist immediately.'
                            : 'No significant glaucoma indicators. Continue routine checkups.',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _generatingPdf ? null : _downloadPdf,
                icon: _generatingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: Text(
                  _generatingPdf ? 'Generating PDF...' : 'Download PDF Report',
                  style: const TextStyle(fontSize: 16),
                ),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
                label: const Text('Return to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Map<String, String> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.folder_open, color: Color(0xFF1565C0)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...data.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      entry.value,
                      style:
                          const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}