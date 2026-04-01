import 'package:Qurbani/faq_page.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/services/admin_payment_service.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:Qurbani/theme/theme.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  final String role;

  static Future<Map<String, dynamic>> Function()? mockProfile;
  static Future<List<String>> Function()? mockCurrencies;
  static Future<Map<String, dynamic>> Function()? mockPaymentSettings;
  static Future<void> Function(String url)? mockOpenLink;

  const SettingsPage({super.key, required this.userId, required this.role});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationSound = true;
  String _selectedLanguage = "English";

  // Payment methods for admins
  List<String> _selectedPaymentMethods = [];
  DateTime? _codDeadline;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    if (widget.role == 'admin') {
      _loadPaymentSettings();
    }
  }

  /// Load notification and language
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationSound = prefs.getBool('notificationSound') ?? true;
      _selectedLanguage = prefs.getString('language') ?? "English";
    });
  }

  /// Load admin payment settings
  Future<void> _loadPaymentSettings() async {
    try {
      final data = SettingsPage.mockPaymentSettings != null
          ? await SettingsPage.mockPaymentSettings!()
          : await PaymentService.getPaymentSettings();

      setState(() {
        _selectedPaymentMethods = [];
        if (_isEnabled(data['allow_cod'])) _selectedPaymentMethods.add('cod');
        if (_isEnabled(data['allow_online'])) {
          _selectedPaymentMethods.add('online');
        }
        _codDeadline = data['cod_deadline'] != null
            ? DateTime.parse(data['cod_deadline'])
            : null;
      });
    } catch (e) {
      ToastUtils.showError(
        _friendlyErrorMessage(
          e,
          fallback: "Unable to load payment settings right now.",
        ),
      );
    }
  }

  

  /// Update notification toggle
  Future<void> _updateNotificationSound(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationSound', val);
    setState(() => _notificationSound = val);
  }

  /// Update admin payment methods
  Future<void> _updatePaymentMethods(List<String> methods) async {
    if (methods.isEmpty) {
      ToastUtils.showError("Select at least one payment method");
      return;
    }

    try {
      await PaymentService.updatePaymentSettings(
        allowCod: methods.contains('cod'),
        allowOnline: methods.contains('online'),
        codDeadline: methods.contains('cod') ? _formatDate(_codDeadline) : null,
      );
      setState(() {
        _selectedPaymentMethods = methods;
        if (!methods.contains('cod')) {
          _codDeadline = null;
        }
      });
      ToastUtils.showSuccess("Payment methods updated");
    } catch (e) {
      ToastUtils.showError(
        _friendlyErrorMessage(
          e,
          fallback: "Unable to update payment methods right now.",
        ),
      );
    }
  }

  /// Update COD deadline
  Future<void> _updateCodDeadline(DateTime? deadline) async {
    try {
      await PaymentService.updatePaymentSettings(
        allowCod: _selectedPaymentMethods.contains('cod'),
        allowOnline: _selectedPaymentMethods.contains('online'),
        codDeadline: _formatDate(deadline),
      );
      setState(() => _codDeadline = deadline);
    } catch (e) {
      ToastUtils.showError(
        _friendlyErrorMessage(
          e,
          fallback: "Unable to update the COD deadline right now.",
        ),
      );
    }
  }

  bool _isEnabled(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    return value?.toString() == '1' || value?.toString().toLowerCase() == 'true';
  }

  String? _formatDate(DateTime? value) {
    if (value == null) return null;
    return DateFormat('yyyy-MM-dd').format(value);
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }



  /// Open external links
  Future<void> _openLink(String url) async {
    if (SettingsPage.mockOpenLink != null) {
      return SettingsPage.mockOpenLink!(url);
    }
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ToastUtils.showError("Could not open link");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader("Language"),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text("App Language"),
            subtitle: Text(_selectedLanguage),
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 16),



          if (widget.role == 'admin') ..._buildAdminPaymentSection(),

          _sectionHeader("Help & Support"),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("FAQ"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqPage()),
              );
            },
          ),

          const Divider(),

          _sectionHeader("Rate & Feedback"),
          ListTile(
            leading: const Icon(Icons.star_rate),
            title: const Text("Rate this App"),
            onTap: () => _openLink(
              "https://play.google.com/store/apps/details?id=your.app.id",
            ),
          ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text("Send Feedback"),
            onTap: () =>
                _openLink("mailto:support@example.com?subject=Feedback"),
          ),
          const Divider(),

          _sectionHeader("Privacy & Security"),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Privacy Policy"),
            onTap: () => _openLink("https://example.com/privacy"),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("Security Tips"),
            onTap: () => _openLink("https://example.com/security"),
          ),
          const Divider(),

          _sectionHeader("Notifications"),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Notification Sound"),
            value: _notificationSound,
            onChanged: _updateNotificationSound,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkBgGradientEnd,
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final languages = ["English", "हिन्दी", "اردو"];
    final prefs = await SharedPreferences.getInstance();

    await showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text("Choose Language"),
        children: languages.map((lang) {
          return RadioListTile<String>(
            title: Text(lang),
            value: lang,
            groupValue: _selectedLanguage,
            onChanged: (val) async {
              if (val != null) {
                await prefs.setString('language', val);
                setState(() => _selectedLanguage = val);
                Navigator.pop(context);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildAdminPaymentSection() {
    return [
      _sectionHeader("Payment Methods"),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgGradientEnd,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Payment Methods",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _selectedPaymentMethods.contains('cod'),
              activeColor: AppTheme.primaryGreen,
              title: const Text("Cash"),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                final methods = List<String>.from(_selectedPaymentMethods);
                if (checked == true) {
                  methods.add('cod');
                } else {
                  methods.remove('cod');
                }
                _updatePaymentMethods(methods);
              },
            ),
            if (_selectedPaymentMethods.contains('cod')) ...[
              const SizedBox(height: 10),
              const Text(
                "COD Payment Deadline *",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    _updateCodDeadline(picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _codDeadline != null
                            ? DateFormat('dd/MM/yyyy').format(_codDeadline!)
                            : "Select Deadline",
                        style: TextStyle(
                          color: _codDeadline != null
                              ? Colors.black
                              : AppTheme.darkBgGradientStart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            CheckboxListTile(
              value: _selectedPaymentMethods.contains('online'),
              activeColor: AppTheme.primaryGreen,
              title: const Text("Online Payment"),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) {
                final methods = List<String>.from(_selectedPaymentMethods);
                if (checked == true) {
                  methods.add('online');
                } else {
                  methods.remove('online');
                }
                _updatePaymentMethods(methods);
              },
            ),
            if (_selectedPaymentMethods.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  "⚠ Select at least one payment method",
                  style: TextStyle(color: AppTheme.warningRed, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      const Divider(height: 32),
    ];
  }
}
