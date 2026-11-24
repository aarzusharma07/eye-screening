import 'package:flutter/material.dart';
import 'referral_report_screen.dart';

class RiskForecastScreen extends StatelessWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;
  final List<dynamic> predictions;
  final bool referralNeeded;
  final String referralReason;

  const RiskForecastScreen({
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

  String _riskLabel() {
    bool hasHigh = predictions.any((p) =>
        (p['risk_category'] as String? ?? '').toLowerCase() == 'high');
    bool hasMedium = predictions.any((p) =>
        (p['risk_category'] as String? ?? '').toLowerCase() == 'medium');
    if (hasHigh) return 'High Risk';
    if (hasMedium) return 'Medium Risk';
    return 'Low Risk';
  }

  Color _riskColor() {
    final label = _riskLabel();
    if (label == 'High Risk') return Colors.red;
    if (label == 'Medium Risk') return Colors.orange;
    return Colors.green;
  }

  IconData _riskIcon() {
    final label = _riskLabel();
    if (label == 'High Risk') return Icons.warning;
    if (label == 'Medium Risk') return Icons.trending_up;
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor();

    return Scaffold(
      appBar: AppBar(title: const Text('Risk Forecast')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Risk summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                children: [
                  Icon(_riskIcon(), color: color, size: 80),
                  const SizedBox(height: 15),
                  Text(
                    _riskLabel(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    referralNeeded
                        ? 'Immediate ophthalmologist evaluation recommended.'
                        : 'Continue routine annual eye check-ups.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Per-eye risk breakdown
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Breakdown by Eye',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...predictions.map((p) {
                      final eye = p['eye'] as String? ?? 'Unknown';
                      
                      // Glaucoma
                      final gCls = (p['glaucoma_class'] ?? p['class'] ?? 'normal') as String;
                      final gProb = ((p['glaucoma_probability'] ?? p['probability'] ?? 0.0) as num).toDouble();
                      final gRisk = (p['glaucoma_risk'] ?? p['risk_category'] ?? 'Low') as String;
                      final gBarColor = gRisk.toLowerCase() == 'high'
                          ? Colors.red
                          : gRisk.toLowerCase() == 'medium'
                              ? Colors.orange
                              : Colors.green;

                      // DR
                      final drCls = (p['dr_class'] ?? 'No DR') as String;
                      final drProb = ((p['dr_probability'] ?? 0.0) as num).toDouble();
                      final drRisk = (p['dr_risk'] ?? 'Low') as String;
                      final drBarColor = drRisk.toLowerCase() == 'high'
                          ? Colors.red
                          : drRisk.toLowerCase() == 'medium'
                              ? Colors.orange
                              : Colors.green;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$eye Eye Analysis',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1565C0)),
                            ),
                            const SizedBox(height: 8),

                            // Glaucoma bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('🩺 Glaucoma: ${gCls.toUpperCase()}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('$gRisk Risk (${(gProb * 100).toStringAsFixed(1)}%)',
                                    style: TextStyle(color: gBarColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: gProb.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(gBarColor),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // DR bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('🩸 Retinopathy: ${drCls.toUpperCase()}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('$drRisk Risk (${(drProb * 100).toStringAsFixed(1)}%)',
                                    style: TextStyle(color: drBarColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: drProb.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(drBarColor),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Risk factor card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Factors Identified',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _riskFactor(Icons.cake,
                        'Age: $patientAge years',
                        patientAge > 60 ? Colors.orange : Colors.green),
                    _riskFactor(Icons.people, 'Gender: $patientGender',
                        Colors.blue),
                    _riskFactor(
                        Icons.timeline,
                        'Diabetes Duration: ${diabetesDuration.toStringAsFixed(1)} years',
                        diabetesDuration > 5 ? Colors.orange : Colors.green),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReferralReportScreen(
                        visitId: visitId,
                        patientName: patientName,
                        patientAge: patientAge,
                        patientGender: patientGender,
                        diabetesDuration: diabetesDuration,
                        predictions: predictions,
                        referralNeeded: referralNeeded,
                        referralReason: referralReason,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.description),
                label: const Text('Generate Referral Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskFactor(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
    );
  }
}