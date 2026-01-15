import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qurbani/widgets/success_error_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:qurbani/services/currency_notifier.dart';
import 'package:qurbani/services/service_profile.dart';
import 'package:qurbani/theme/theme.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  final String role;

  const SettingsPage({super.key, required this.userId, required this.role});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationSound = true;
  String _selectedLanguage = "English";
  String? _selectedCurrency;
  final List<String> _currencyOptions = ["USD", "EUR", "GBP", "AED", "INR"];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserCurrency();
  }

  /// Load notification & language settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationSound = prefs.getBool('notificationSound') ?? true;
      _selectedLanguage = prefs.getString('language') ?? "English";
    });
  }

  /// Load user-specific currency from backend or local storage
  Future<void> _loadUserCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final notifier = context.read<CurrencyNotifier>();

    try {
      final profile = await ProfileService.getProfile();
      final currency =
          profile['currency'] ?? prefs.getString('currency') ?? "USD";

      setState(() => _selectedCurrency = currency);
      notifier.setCurrency(currency);
      await prefs.setString('currency', currency);
    } catch (_) {
      final localCurrency = prefs.getString('currency') ?? "USD";
      setState(() => _selectedCurrency = localCurrency);
      notifier.setCurrency(localCurrency);
    }
  }

  /// Update notification toggle
  Future<void> _updateNotificationSound(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationSound', val);
    setState(() => _notificationSound = val);
  }

  /// Update user currency
  Future<void> _updateUserCurrency(String val) async {
    final notifier = context.read<CurrencyNotifier>();

    try {
      await ProfileService.updateCurrency(val);
      await _setCurrency(val);

      notifier.setCurrency(val);

      ToastUtils.showSuccess("Currency updated to $val");
      
    } catch (e) {
      ToastUtils.showError("Failed to update currency: $e");

    }
  }

  Future<void> _setCurrency(String val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', val);
    setState(() => _selectedCurrency = val);
  }

  /// Open external links
  Future<void> _openLink(String url) async {
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

          _sectionHeader("Currency"),
          Consumer<CurrencyNotifier>(
            builder: (_, notifier, __) {
              return DropdownButtonFormField<String>(
                value: _selectedCurrency ?? notifier.currency,
                items: _currencyOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _updateUserCurrency(val);
                },
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: "Currency",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 32),

          _sectionHeader("Help & Support"),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("FAQ"),
            onTap: () => _openLink("https://example.com/faq"),
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
          color: Colors.black54,
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
}
