import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'image_upload_screen.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends State<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  final _diabetesController = TextEditingController();
  final _prevEyeNotesController = TextEditingController();

  String? _selectedGender;
  bool _hasHypertension = false;
  bool _hasPrevEyeIssues = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _diabetesController.dispose();
    _prevEyeNotesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      setState(() => _errorMsg = 'Please select a gender.');
      return;
    }

    final name = _nameController.text.trim();
    final age = int.tryParse(_ageController.text.trim()) ?? 0;
    final diabetes = double.tryParse(_diabetesController.text.trim()) ?? 0.0;
    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
    final village = _villageController.text.trim().isEmpty ? null : _villageController.text.trim();
    final prevNotes = _hasPrevEyeIssues && _prevEyeNotesController.text.trim().isNotEmpty
        ? _prevEyeNotesController.text.trim()
        : null;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    // 1. Register patient
    final patient = await ApiService.registerPatient(
      name: name,
      age: age,
      gender: _selectedGender!,
      phone: phone,
      village: village,
      diabetesDuration: diabetes,
      hasHypertension: _hasHypertension,
      hasPrevEyeIssues: _hasPrevEyeIssues,
      prevEyeNotes: prevNotes,
    );

    if (patient == null) {
      setState(() {
        _loading = false;
        _errorMsg = 'Failed to register patient. Check your connection.';
      });
      return;
    }

    final patientId = patient['id'] as int;

    // 2. Create a visit for this patient
    final visit = await ApiService.createVisit(patientId);

    if (visit == null) {
      setState(() {
        _loading = false;
        _errorMsg = 'Patient registered but failed to create visit.';
      });
      return;
    }

    final visitId = visit['id'] as int;

    setState(() => _loading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageUploadScreen(
            visitId: visitId,
            patientName: name,
            patientAge: age,
            patientGender: _selectedGender!,
            diabetesDuration: diabetes,
            village: village,
            phone: phone,
            hasHypertension: _hasHypertension,
            hasPrevEyeIssues: _hasPrevEyeIssues,
          ),
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
    Color activeColor = const Color(0xFF1565C0),
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: value ? activeColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? activeColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: value ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Patient Registration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person_add, size: 38, color: Colors.white),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Register New Patient',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Complete all fields for accurate AI screening',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Basic Info ───────────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Basic Information'),

                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Patient Full Name *',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageController,
                              decoration: const InputDecoration(
                                labelText: 'Age *',
                                prefixIcon: Icon(Icons.cake),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final age = int.tryParse(v ?? '');
                                if (age == null || age < 1 || age > 120) {
                                  return 'Enter valid age';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Gender *',
                                prefixIcon: Icon(Icons.wc),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (value) => setState(() {
                                _selectedGender = value;
                                _errorMsg = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          hintText: 'Optional',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _villageController,
                        decoration: const InputDecoration(
                          labelText: 'Village / Location',
                          prefixIcon: Icon(Icons.location_on),
                          hintText: 'e.g. Rampur, Block A',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Medical History ──────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Medical History'),

                      TextFormField(
                        controller: _diabetesController,
                        decoration: const InputDecoration(
                          labelText: 'Diabetes Duration',
                          prefixIcon: Icon(Icons.bloodtype),
                          hintText: '0 if none',
                          suffixText: 'years',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Blood Pressure (Hypertension)',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildToggleChip(
                            label: 'Yes',
                            value: _hasHypertension,
                            onChanged: (v) => setState(() => _hasHypertension = v),
                            activeColor: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          _buildToggleChip(
                            label: 'No',
                            value: !_hasHypertension,
                            onChanged: (v) => setState(() => _hasHypertension = !v),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Previous Eye Issues',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildToggleChip(
                            label: 'Yes',
                            value: _hasPrevEyeIssues,
                            onChanged: (v) => setState(() => _hasPrevEyeIssues = v),
                            activeColor: Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          _buildToggleChip(
                            label: 'No',
                            value: !_hasPrevEyeIssues,
                            onChanged: (v) => setState(() => _hasPrevEyeIssues = !v),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),

                      if (_hasPrevEyeIssues) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _prevEyeNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Describe previous eye issues',
                            prefixIcon: Icon(Icons.notes),
                            hintText: 'e.g. cataract surgery, glaucoma diagnosis, trauma...',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (_errorMsg != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMsg!,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Submit ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _loading ? 'Registering...' : 'Register & Proceed to Capture',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Progress indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(0xFF1565C0),
                      child: Text('1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Step 1 of 5 — Patient Registration',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}