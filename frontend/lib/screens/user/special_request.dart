import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:Qurbani/services/request_service.dart';
import 'package:Qurbani/screens/user/user_home_screen.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';

class SpecialRequestPage extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String? orderId;
  final String? userId;

  const SpecialRequestPage({
    super.key,
    required this.orderData,
    this.orderId,
    this.userId,
  });

  @override
  State<SpecialRequestPage> createState() => _SpecialRequestPageState();
}

class _SpecialRequestPageState extends State<SpecialRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _loading = false;

  // Constants to match the UI screenshot
  static const Color scaffoldBg = Color(0xffF9F4F1);

  String _displayMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  String _valueFromOrder(List<String> keys) {
    for (final key in keys) {
      final value = widget.orderData[key];
      final normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _resolveOrderId() {
    final explicitOrderId = widget.orderId?.trim() ?? '';
    if (explicitOrderId.isNotEmpty) {
      return explicitOrderId;
    }
    return _valueFromOrder(['id', 'orderId', 'order_id']);
  }

  String _resolveUserId() {
    final explicitUserId = widget.userId?.trim() ?? '';
    if (explicitUserId.isNotEmpty) {
      return explicitUserId;
    }
    return _valueFromOrder(['user_id', 'userId']);
  }

  String _resolveUserName() {
    return _valueFromOrder(['userName', 'user_name', 'name']);
  }

  String _resolveRole() {
    final role = _valueFromOrder(['role']);
    return role.isEmpty ? 'user' : role;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final orderId = _resolveOrderId();
    final userId = _resolveUserId();

    if (kDebugMode) {
      debugPrint(
        '[SpecialRequestPage] submit orderId=$orderId userId=$userId orderDataKeys=${widget.orderData.keys.toList()}',
      );
    }

    if (orderId.isEmpty) {
      ToastUtils.showError(
        "We couldn't identify this order. Please open it again and try.",
      );
      return;
    }

    if (userId.isEmpty) {
      ToastUtils.showError(
        "We couldn't identify your account. Please log in again and try.",
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await RequestService.submitRequest(
        orderId,
        userId,
        _titleController.text.trim(),
        _descriptionController.text.trim(),
      );

      if (!mounted) return;

      ToastUtils.showSuccess('Special request submitted successfully');

      final resolvedUserName = _resolveUserName();
      final userName = resolvedUserName.isEmpty ? 'User' : resolvedUserName;
      final role = _resolveRole();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(id: userId, name: userName, role: role),
        ),
        (_) => false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SpecialRequestPage] submit failed error=$e');
      }
      ToastUtils.showError(_displayMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Special Qurbani Request',
          style: TextStyle(
            color: Color(0xff4A4A4A),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              const Text(
                'Request custom arrangements for your Qurbani. Our team will review and respond.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
              const SizedBox(height: 30),

              // Central Card Container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.bgGradientEnd,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Icon
                      Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: Colors.orange.shade300,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Submit Your Special Request',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff333333),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Request custom arrangements for your Qurbani. Our team will review and respond.',
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                      const Divider(height: 32, thickness: 0.8),

                      // Request Title Field
                      _buildLabel('Request Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration(
                          'Single goat Qurbani on Day 2 with video recording',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter a title'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // Special Instructions Field
                      _buildLabel('Special Instructions'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          'Enter any special instructions...',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Please enter instructions'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Examples: Specific dua or method, meat distribution preference, slaughter video request, particular animal size, etc.',
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: AppTheme.bgGradientEnd,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.bgGradientEnd,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Submit Request',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Color(0xff444444),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
      filled: true,
      fillColor: AppTheme.bgGradientEnd,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.warningRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.warningRed, width: 1.5),
      ),
    );
  }
}
