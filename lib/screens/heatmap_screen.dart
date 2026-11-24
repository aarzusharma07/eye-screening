import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'risk_forecast_screen.dart';

class HeatmapScreen extends StatefulWidget {
  final int visitId;
  final String patientName;
  final int patientAge;
  final String patientGender;
  final double diabetesDuration;
  final List<dynamic> predictions;
  final bool referralNeeded;
  final String referralReason;

  const HeatmapScreen({
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
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  String _selectedDisease = 'glaucoma';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Explainability Heatmaps')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Disease Selector Segmented Control
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDisease = 'glaucoma'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedDisease == 'glaucoma' ? const Color(0xFF1565C0) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '🩺 Glaucoma (Disc)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedDisease == 'glaucoma' ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDisease = 'dr'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedDisease == 'dr' ? const Color(0xFFE65100) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '🩸 Retinopathy (DR)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _selectedDisease == 'dr' ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDisease == 'glaucoma'
                          ? 'Glaucoma Optic Cup/Disc Localization'
                          : 'Diabetic Retinopathy Microvascular Localization',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedDisease == 'glaucoma'
                          ? 'Grad-CAM highlights optic disc margins and cup excavation areas.'
                          : 'Grad-CAM highlights microaneurysms, hemorrhages, and retinal exudate regions.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    _HeatmapEyePanel(
                      key: ValueKey('left_$_selectedDisease'),
                      visitId: widget.visitId,
                      eye: 'left',
                      disease: _selectedDisease,
                      label: 'Left Eye Heatmap (${_selectedDisease.toUpperCase()})',
                    ),
                    const SizedBox(height: 20),
                    _HeatmapEyePanel(
                      key: ValueKey('right_$_selectedDisease'),
                      visitId: widget.visitId,
                      eye: 'right',
                      disease: _selectedDisease,
                      label: 'Right Eye Heatmap (${_selectedDisease.toUpperCase()})',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Warm colors (Red/Yellow) indicate high convolutional activation and influence on the model\'s prediction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RiskForecastScreen(
                        visitId: widget.visitId,
                        patientName: widget.patientName,
                        patientAge: widget.patientAge,
                        patientGender: widget.patientGender,
                        diabetesDuration: widget.diabetesDuration,
                        predictions: widget.predictions,
                        referralNeeded: widget.referralNeeded,
                        referralReason: widget.referralReason,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up),
                label: const Text('Continue to Risk Forecast'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapEyePanel extends StatefulWidget {
  final int visitId;
  final String eye;
  final String disease;
  final String label;

  const _HeatmapEyePanel({
    super.key,
    required this.visitId,
    required this.eye,
    required this.disease,
    required this.label,
  });

  @override
  State<_HeatmapEyePanel> createState() => _HeatmapEyePanelState();
}

class _HeatmapEyePanelState extends State<_HeatmapEyePanel> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final url = ApiService.getHeatmapUrl(widget.visitId, widget.eye, widget.disease);
    final headers = ApiService.getAuthHeaders();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _hasError
              ? Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Heatmap unavailable',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Image.network(
                  url,
                  headers: headers,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (ctx, error, stackTrace) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _hasError = true);
                    });
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Heatmap unavailable',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}