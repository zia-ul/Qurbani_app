import 'dart:async';

import 'package:Qurbani/authentication/login_page.dart';
import 'package:Qurbani/models/user_model.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/services/phone_email_config.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:Qurbani/widgets/success_error_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:phone_email_auth/phone_email_auth.dart';

class PhoneVerificationPage extends StatefulWidget {
  final String email;
  final String? expectedCountryCode;
  final String? expectedPhoneNumber;

  const PhoneVerificationPage({
    super.key,
    required this.email,
    this.expectedCountryCode,
    this.expectedPhoneNumber,
  });

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  bool _isVerifying = false;
  bool _phoneVerified = false;
  bool _verificationNotRequired = false;
  bool _isLoadingPhoneContext = false;
  String? _verifiedPhoneLabel;
  String? _resolvedCountryCode;
  String? _resolvedPhoneNumber;

  String get _expectedPhoneLabel {
    final countryCode = _resolvedCountryCode?.trim() ?? '';
    final phoneNumber = _resolvedPhoneNumber?.trim() ?? '';
    return '$countryCode $phoneNumber'.trim();
  }

  String _normalizePhoneNumber(String? phoneNumber) {
    return (phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
  }

  String? _normalizeCountryCode(String? countryCode) {
    final normalized = (countryCode ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _displayMessage(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _resolvedCountryCode = _normalizeCountryCode(widget.expectedCountryCode);
    _resolvedPhoneNumber = _normalizePhoneNumber(widget.expectedPhoneNumber);
    _loadPhoneVerificationContext();
  }

  Future<void> _loadPhoneVerificationContext({bool showErrors = false}) async {
    if (_isLoadingPhoneContext || (_resolvedPhoneNumber?.isNotEmpty ?? false)) {
      return;
    }

    setState(() => _isLoadingPhoneContext = true);

    try {
      final context = await AuthService.fetchPhoneVerificationContext(
        widget.email,
      );

      if (!mounted) return;

      final normalizedPhoneNumber = _normalizePhoneNumber(context.phoneNumber);
      final normalizedCountryCode = _normalizeCountryCode(context.countryCode);
      final resolvedLabel = '$normalizedCountryCode $normalizedPhoneNumber'
          .trim();
      final isSuperAdmin =
          UserModel.normalizeRole(context.role) == 'super_admin';

      setState(() {
        _verificationNotRequired =
            context.verificationNotRequired || isSuperAdmin;
        _resolvedCountryCode = normalizedCountryCode;
        _resolvedPhoneNumber = normalizedPhoneNumber;

        if (context.isPhoneVerified && resolvedLabel.isNotEmpty) {
          _phoneVerified = true;
          _verifiedPhoneLabel = resolvedLabel;
        }
      });
    } catch (error, stack) {
      AppLogger.error(
        'Unable to load registered phone number for verification',
        error,
        stack,
      );

      if (showErrors && mounted) {
        ToastUtils.showError(_displayMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPhoneContext = false);
      }
    }
  }

  Future<PhoneEmailUserModel> _fetchVerifiedUser(String accessToken) {
    final completer = Completer<PhoneEmailUserModel>();

    PhoneEmail.getUserInfo(
      accessToken: accessToken,
      clientId: PhoneEmailConfig.clientId,
      onSuccess: (userData) {
        if (!completer.isCompleted) {
          completer.complete(userData);
        }
      },
    ).catchError((error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    return completer.future;
  }

  Future<void> _verifyPhone(String accessToken) async {
    if (!PhoneEmailConfig.isConfigured) {
      ToastUtils.showError(PhoneEmailConfig.missingClientIdMessage);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final userData = await _fetchVerifiedUser(accessToken);

      await AuthService.verifyPhone(
        email: widget.email,
        accessToken: accessToken,
        clientId: PhoneEmailConfig.clientId,
      );

      if (!mounted) return;

      setState(() {
        _phoneVerified = true;
        _verifiedPhoneLabel =
            '${userData.countryCode ?? ''} ${userData.phoneNumber ?? ''}'
                .trim();
      });

      ToastUtils.showSuccess(
        'Phone verified successfully. Finish email verification if it is still pending, then log in.',
      );
    } catch (error, stack) {
      AppLogger.error('Phone verification failed', error, stack);
      ToastUtils.showError(_displayMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _openPhoneLogin() async {
    if (_verificationNotRequired) {
      ToastUtils.showSuccess('Verification is not required for this account.');
      _goToLogin();
      return;
    }

    if (_isVerifying || _isLoadingPhoneContext) {
      if (_isLoadingPhoneContext) {
        ToastUtils.showError(
          'Loading your registered phone number. Please wait a moment.',
        );
      }
      return;
    }

    if (!PhoneEmailConfig.isConfigured) {
      ToastUtils.showError(PhoneEmailConfig.missingClientIdMessage);
      return;
    }

    if ((_resolvedPhoneNumber ?? '').isEmpty) {
      await _loadPhoneVerificationContext(showErrors: true);
    }

    if (!mounted) {
      return;
    }

    if ((_resolvedPhoneNumber ?? '').isEmpty) {
      ToastUtils.showError(
        'No registered phone number was found for this account.',
      );
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => _PhoneEmailAuthScreen(
          phoneNumber: _resolvedPhoneNumber ?? '',
          countryCode: _resolvedCountryCode,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final errorMessage = result['error']?.toString().trim();
    if (errorMessage != null && errorMessage.isNotEmpty) {
      ToastUtils.showError(errorMessage);
      return;
    }

    final loginData = result[AppConstant.authResponse];
    if (loginData is! LoginModel) {
      return;
    }

    final accessToken = loginData.accessTokenn?.trim() ?? '';
    if (accessToken.isEmpty) {
      ToastUtils.showError(
        'Phone.Email did not return an access token for verification.',
      );
      return;
    }

    await _verifyPhone(accessToken);
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialEmail: widget.email),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _verificationNotRequired
        ? _VerificationNotRequiredContent(
            email: widget.email,
            onContinue: _goToLogin,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verify Your Account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Login is enabled only after both checks are complete: email link verification and phone OTP verification.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade800),
              ),
              const SizedBox(height: 18),
              _InfoTile(
                icon: Icons.email_outlined,
                title: 'Registered email',
                value: widget.email,
              ),
              if (_expectedPhoneLabel.isNotEmpty) ...[
                const SizedBox(height: 10),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Registered phone',
                  value: _expectedPhoneLabel,
                ),
              ],
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next steps',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Open the email verification link we sent.'),
                    SizedBox(height: 4),
                    Text('2. Verify the same phone number with OTP below.'),
                    SizedBox(height: 4),
                    Text('3. Return to login after both are complete.'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!PhoneEmailConfig.isConfigured)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    PhoneEmailConfig.missingClientIdMessage,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                )
              else if (_isVerifying)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                )
              else if (_isLoadingPhoneContext)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openPhoneLogin,
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(
                          _expectedPhoneLabel.isNotEmpty
                              ? 'Send OTP to Registered Phone'
                              : 'Verify Phone with OTP',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (_expectedPhoneLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Phone.Email will open with your registered number prefilled.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              if (!_isVerifying &&
                  !_isLoadingPhoneContext &&
                  PhoneEmailConfig.isConfigured &&
                  _expectedPhoneLabel.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Enter the correct account email and we will load the registered phone number before opening Phone.Email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                ),
              ],
              if (_verifiedPhoneLabel != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Verified phone: $_verifiedPhoneLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _phoneVerified ? _goToLogin : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue to Login'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _goToLogin,
                child: const Text(
                  'I already verified everything, take me to login',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.primaryGreen),
                ),
              ),
            ],
          );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 15,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8E6D1), Color(0xFFDBD299)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationNotRequiredContent extends StatelessWidget {
  final String email;
  final VoidCallback onContinue;

  const _VerificationNotRequiredContent({
    required this.email,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.verified_user_outlined,
          color: AppTheme.primaryGreen,
          size: 42,
        ),
        const SizedBox(height: 12),
        const Text(
          'Verification Not Required',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          email,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade800),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Continue to Login'),
        ),
      ],
    );
  }
}

class _PhoneEmailAuthScreen extends StatefulWidget {
  final String phoneNumber;
  final String? countryCode;

  const _PhoneEmailAuthScreen({required this.phoneNumber, this.countryCode});

  @override
  State<_PhoneEmailAuthScreen> createState() => _PhoneEmailAuthScreenState();
}

class _PhoneEmailAuthScreenState extends State<_PhoneEmailAuthScreen> {
  final GlobalKey _webViewKey = GlobalKey();
  final PhoneEmail _phoneEmail = PhoneEmail();

  InAppWebViewController? _webViewController;
  bool _handlerAttached = false;

  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'\D'), '');
  }

  String? _normalizeCountryCode(String? countryCode) {
    final normalized = (countryCode ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _loadAuthenticationUrl() async {
    final deviceId = (_phoneEmail.deviceId?.isNotEmpty ?? false)
        ? _phoneEmail.deviceId
        : await PhoneEmail.getUDID();

    final queryParameters = <String, String>{
      AppConstant.clientId: _phoneEmail.clientId,
      AppConstant.device: deviceId ?? '',
      AppConstant.authType: '5',
    };

    final normalizedPhoneNumber = _normalizePhoneNumber(widget.phoneNumber);
    if (normalizedPhoneNumber.isNotEmpty) {
      queryParameters['user_phone_no'] = normalizedPhoneNumber;
    }

    final normalizedCountryCode = _normalizeCountryCode(widget.countryCode);
    if (normalizedCountryCode != null) {
      queryParameters['country_code'] = normalizedCountryCode;
    }

    final authenticationUrl = Uri.parse(
      AppConstant.authUrl,
    ).replace(queryParameters: queryParameters).toString();

    AppLogger.info(
      normalizedPhoneNumber.isNotEmpty
          ? 'Opening Phone.Email with registered phone prefilled'
          : 'Opening Phone.Email without prefilled phone number',
    );

    await _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(authenticationUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            AppConstant.authViewTitle,
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
        body: InAppWebView(
          key: _webViewKey,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            mediaPlaybackRequiresUserGesture: false,
            cacheEnabled: true,
            allowsInlineMediaPlayback: true,
          ),
          onWebViewCreated: (controller) async {
            _webViewController = controller;
            await _loadAuthenticationUrl();
          },
          onLoadStart: (controller, url) {
            if (_handlerAttached) {
              return;
            }

            _handlerAttached = true;
            controller.addJavaScriptHandler(
              handlerName: AppConstant.sendTokenToApp,
              callback: (arguments) {
                if (arguments.isEmpty || arguments.first is! Map) {
                  Navigator.pop(context, {
                    'error': 'Phone.Email returned an unexpected response.',
                  });
                  return;
                }

                Navigator.pop(context, {
                  AppConstant.authResponse: LoginModel.fromJson(
                    Map<String, dynamic>.from(arguments.first as Map),
                  ),
                });
              },
            );
          },
          onReceivedError: (controller, request, error) {
            Navigator.pop(context, {
              'error':
                  'Unable to open Phone.Email right now. ${error.description}',
            });
          },
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
