import 'package:flutter/material.dart';
import 'ai_results_screen.dart';

class QualityCheckScreen extends StatelessWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;
  final Map<String, dynamic>? leftQuality;
  final Map<String, dynamic>? rightQuality;

  const QualityCheckScreen({
    super.key,
    required this.visitId,
    required this.patientName,
    required this.patientAge,
    required this.patientGender,
    required this.diabetesDuration,
    this.leftQuality,
    this.rightQuality,
  });

  String _qualityLabel(Map<String, dynamic>? q) {
    if (q == null) return 'N/A';
    return (q['quality'] as String? ?? 'Unknown').toUpperCase();
  }

  Color _qualityColor(Map<String, dynamic>? q) {
    if (q == null) return Colors.grey;
    final quality = (q['quality'] as String? ?? '').toLowerCase();
    if (quality == 'good') return Colors.green;
    if (quality == 'acceptable') return Colors.orange;
    return Colors.red;
  }

  String _scoreLabel(dynamic score) {
    if (score == null) return 'Good';
    final val = (score as num).toDouble();
    if (val <= 1.0) {
      if (val >= 0.7) return 'Good';
      if (val >= 0.4) return 'Acceptable';
      return 'Poor';
    }
    if (val >= 70) return 'Good';
    if (val >= 40) return 'Acceptable';
    return 'Poor';
  }

  bool get _overallGood {
    final lq = (leftQuality?['quality'] as String? ?? '').toLowerCase();
    final rq = (rightQuality?['quality'] as String? ?? '').toLowerCase();
    return lq != 'poor' && rq != 'poor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quality Check')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Overall quality status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _overallGood ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: _overallGood ? Colors.green : Colors.red,
                    width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    _overallGood ? Icons.check_circle : Icons.warning,
                    color: _overallGood ? Colors.green : Colors.red,
                    size: 80,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _overallGood
                        ? 'Image Quality: Good'
                        : 'Image Quality: Poor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _overallGood ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Left Eye Quality
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye,
                            color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Text(
                          'Left Eye — ${_qualityLabel(leftQuality)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _qualityColor(leftQuality),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _row('Focus', _scoreLabel(leftQuality?['focus_score'] ?? leftQuality?['focus'])),
                    _row('Lighting', _scoreLabel(leftQuality?['lighting_score'] ?? leftQuality?['lighting'])),
                    _row('Clarity', _scoreLabel(leftQuality?['clarity_score'] ?? leftQuality?['clarity'])),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Right Eye Quality
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye,
                            color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Text(
                          'Right Eye — ${_qualityLabel(rightQuality)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _qualityColor(rightQuality),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _row('Focus', _scoreLabel(rightQuality?['focus_score'] ?? rightQuality?['focus'])),
                    _row('Lighting', _scoreLabel(rightQuality?['lighting_score'] ?? rightQuality?['lighting'])),
                    _row('Clarity', _scoreLabel(rightQuality?['clarity_score'] ?? rightQuality?['clarity'])),
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
                      builder: (context) => AIResultsScreen(
                        visitId: visitId,
                        patientName: patientName,
                        patientAge: patientAge,
                        patientGender: patientGender,
                        diabetesDuration: diabetesDuration,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Proceed to AI Screening'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}