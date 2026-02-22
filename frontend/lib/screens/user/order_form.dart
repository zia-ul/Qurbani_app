import 'dart:convert'; // For JSON parsing
// import 'package:Qurbani/services/currency_notifier.dart';
import 'package:Qurbani/models/admin_order_config.dart';
import 'package:Qurbani/services/auth_service.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:Qurbani/services/order_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/screens/user/payment_processing_page.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

/// Represents a shareholder/participant in the Qurbani order.
///
/// This class holds all the personal information and address details
/// required for a single shareholder to participate in a Qurbani order.
/// Each shareholder represents one share of an animal that will be
/// sacrificed on behalf of them during Eid al-Adha.
///
/// Properties:
/// - [nameController]: Text editing controller for the shareholder's full name
/// - [guardianController]: Text editing controller for father/guardian name
/// - [addressController]: Text editing controller for street/house address
/// - [postalCodeController]: Text editing controller for postal code
/// - [useSavedAddress]: Boolean flag to use the user's saved address instead of entering a new one
/// - [qurbaniDay]: The day of Qurbani (Day 1, Day 2, or Day 3) - represents when the sacrifice will be performed
/// - [selectedCountryName]: Name of the selected country
/// - [countryISO]: ISO country code for API calls
/// - [states]: List of states/provinces in the selected country
/// - [cities]: List of cities in the selected state
/// - [selectedState]: Currently selected state/province
/// - [selectedCity]: Currently selected city
class Shareholder {
  /// Controller for the shareholder's full name input field.
  /// Used to capture and manage the text input for the shareholder's name.
  final TextEditingController nameController = TextEditingController();

  /// Controller for the father/guardian name input field.
  /// Required for identification purposes in many Muslim communities.
  final TextEditingController guardianController = TextEditingController();

  /// Controller for the street/house address input field.
  /// Contains the detailed address information for delivery purposes.
  final TextEditingController addressController = TextEditingController();

  /// Controller for the postal code input field.
  /// Used for address verification and delivery formatting.
  final TextEditingController postalCodeController = TextEditingController();

  // bool useLiveLocation = false;
  // double? latitude;
  // double? longitude;

  /// Flag indicating whether to use the saved address from the user's profile
  /// instead of manually entering address details.
  /// When true, address fields will be pre-populated from saved user data.
  bool useSavedAddress = false;

  /// The day on which the Qurbani sacrifice will be performed for this shareholder.
  /// Options are 'Day 1', 'Day 2', or 'Day 3' corresponding to the three days
  /// of Eid al-Adha (Days 10, 11, and 12 of Dhul Hijjah).
  String qurbaniDay = 'Day 1';

  /// The name of the selected country for delivery.
  /// Used for address construction and delivery calculations.
  String? selectedCountryName;

  /// The ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB', 'PK').
  /// Required for API calls and country-specific processing.
  String? countryISO;

  /// List of states/provinces available in the selected country.
  /// Populated asynchronously when a country is selected using the
  /// country_state_city package API.
  List<csc.State> states = [];

  /// List of cities available in the selected state.
  /// Populated asynchronously when a state is selected.
  List<csc.City> cities = [];

  /// The currently selected state/province from the available [states] list.
  /// Used to determine which cities to load and for address construction.
  csc.State? selectedState;

  /// The currently selected city from the available [cities] list.
  /// Used for address construction and delivery calculations.
  csc.City? selectedCity;

  /// Disposes all TextEditingController resources to prevent memory leaks.
  /// This method should be called when the Shareholder object is no longer
  /// needed, typically when removing a shareholder from the order or when
  /// the order form is closed.
  void dispose() {
    nameController.dispose();
    guardianController.dispose();
    addressController.dispose();
    postalCodeController.dispose();
  }
}

/// The main page widget for creating a Qurbani order.
///
/// This StatefulWidget allows users to:
/// - Add one or more shareholders (participants) for the Qurbani order
/// - Enter personal information and address details for each shareholder
/// - Select a Qurbani day (Day 1, 2, or 3) for each shareholder
/// - Choose between payment methods (Cash on Delivery or Online)
/// - Review pricing and place the order
///
/// The widget requires an [adminId] parameter to fetch admin-specific
/// configuration, pricing, and payment settings.
class QurbaniOrderPage extends StatefulWidget {
  /// The unique identifier of the admin/vendor from whom the order is being placed.
  /// This is used to fetch admin-specific configuration, pricing, and payment settings.
  final String adminId;

  /// Creates a new QurbaniOrderPage widget.
  ///
  /// The [adminId] parameter is required and must correspond to a valid
  /// admin in the system who has configured their order settings.
  const QurbaniOrderPage({super.key, required this.adminId});

  @override
  State<QurbaniOrderPage> createState() => _QurbaniOrderPageState();
}

/// State class for QurbaniOrderPage.
///
/// Manages all the state required for the order form including:
/// - List of shareholders
/// - Pricing and payment settings from the admin
/// - Form validation and submission
class _QurbaniOrderPageState extends State<QurbaniOrderPage> {
  /// Starting color for the background gradient (warm beige).
  /// Used to create a visually appealing gradient background.
  final Color bgGradientStart = const Color(0xffF2E8D5);

  /// Ending color for the background gradient (white).
  /// Creates a smooth transition from warm beige to white.
  final Color bgGradientEnd = const Color(0xffFFFFFF);

  /// List of shareholders to be included in this order.
  /// Each Shareholder object contains personal info and address details.
  final List<Shareholder> _shareholders = [];

  /// Currently selected payment method.
  /// Options: 'Cash' (Cash on Delivery) or 'Online' (Online Payment).
  /// This value is dynamically updated based on admin payment settings.
  String _paymentMethod = 'Cash'; // Will be updated dynamically

  /// Flag indicating whether the form is currently submitting an order.
  /// When true, the submit button is disabled and a loading indicator is shown.
  bool _isLoading = false;

  /// Flag indicating whether Cash on Delivery (COD) payment is allowed.
  /// Determined by admin payment settings fetched from the server.
  bool _allowCOD = false;

  /// Flag indicating whether Online payment is allowed.
  /// Determined by admin payment settings fetched from the server.
  bool _allowOnline = true;

  /// Flag indicating whether payment settings have been loaded from the server.
  /// Used to show loading state until all required data is fetched.
  bool _paymentSettingsLoaded = false;

  /// Base URL for API calls, loaded from environment configuration.
  /// Points to the backend server endpoint.
  static final String? _baseUrl = dotenv.env['BASE_URL'];

  /// Deadline for Cash on Delivery payment.
  /// If the current date is past this deadline, COD is no longer available
  /// and a late fee may be applied.
  DateTime? _codDeadline;

  /// Pricing information fetched from the admin.
  /// Contains:
  /// - price_per_share: Price for one share of Qurbani
  /// - delivery_type: 'free' or 'paid'
  /// - delivery_fee: Fee for delivery if type is 'paid'
  Map<String, dynamic>? _pricing;

  /// Admin order configuration containing available shares and settings.
  /// Retrieved from the admin's order configuration endpoint.
  AdminOrderConfig? _orderConfig;

  /// Flag indicating whether the order configuration is still being loaded.
  /// Used to show initial loading state.
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _fetchPricing();
    _fetchPaymentSettings();
    _fetchSavedAddress();
    _fetchAdminOrderConfig(widget.adminId);
  }

  @override
  void dispose() {
    for (var s in _shareholders) {
      s.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _savedAddress;

  int get _remainingShares {
    if (_orderConfig == null) return 0;
    return _orderConfig!.remainingShares.floor();
  }

  Future<void> _fetchSavedAddress() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'token');
      if (token == null) return;

      final res = await http.get(
        Uri.parse("$_baseUrl/users/profile/address"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);

      // 🔒 ensure minimum usable fields
      if (data['country_iso'] == null ||
          data['country'] == null ||
          data['state'] == null ||
          data['city'] == null) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _savedAddress = data;
      });
    } catch (e, stack) {
      AppLogger.error("Failed to fetch saved address", e, stack);
    }
  }

  Future<void> _fetchAdminOrderConfig(String adminId) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        AppLogger.error("Admin order config fetch failed: token is null");
        return;
      }

      final res = await http.get(
        Uri.parse("$_baseUrl/admins/$adminId/order-config"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        AppLogger.error(
          "Failed to fetch admin order config. Status: ${res.statusCode}, Body: ${res.body}",
        );
        return;
      }

      final data = jsonDecode(res.body);

      if (!mounted) return;
      setState(() {
        _orderConfig = AdminOrderConfig.fromJson(data);

        // ✅ Add first shareholder only if shares exist
        if (_shareholders.isEmpty && remainingShares > 0) {
          _shareholders.add(Shareholder());
        }
      });
    } catch (e, stack) {
      AppLogger.error("Error fetching admin order config", e, stack);
    } finally {
      if (mounted) {
        setState(() => _loadingConfig = false);
      }
    }
  }

  Future<void> _fetchPaymentSettings() async {
    try {
      final res = await http.get(
        Uri.parse("$_baseUrl/admins/${widget.adminId}/payment-settings"),
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to load payment settings");
      }

      final data = jsonDecode(res.body);

      setState(() {
        _allowCOD = data['allow_cod'] == 1;
        _allowOnline = data['allow_online'] == 1;

        _codDeadline = data['cod_deadline'] != null
            ? DateTime.parse(data['cod_deadline'])
            : null;

        _paymentMethod = _allowOnline ? 'Online' : 'Cash';
      });
    } catch (e, stack) {
      AppLogger.error("Failed to load payment settings", e, stack);
      Fluttertoast.showToast(
        msg: "Error loading payment settings",
        backgroundColor: AppTheme.warningRed,
      );

      Fluttertoast.showToast(
        msg: "Error loading payment settings",
        backgroundColor: AppTheme.warningRed,
      );
    } finally {
      // 🔥 REQUIRED
      if (mounted) {
        setState(() => _paymentSettingsLoaded = true);
      }
    }
  }

  Future<void> _fetchPricing() async {
    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("Not authenticated");
      }

      final res = await http.get(
        Uri.parse("$_baseUrl/admins/${widget.adminId}/share-pricing"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Failed to load pricing");
      }

      setState(() {
        _pricing = jsonDecode(res.body);
      });
    } catch (e, stack) {
      AppLogger.error("Failed to fetch share pricing", e, stack);
      Fluttertoast.showToast(
        msg: "Error loading price per share",
        backgroundColor: AppTheme.warningRed,
      );
    }
  }

  void _addShareholder() {
    if (_orderConfig == null) return; // 🔒 guard

    if (_shareholders.length >= remainingShares) {
      Fluttertoast.showToast(
        msg: "No more shares available",
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() {
      _shareholders.add(Shareholder());
    });
  }

  void _removeShareholder(int index) {
    setState(() {
      _shareholders[index].dispose();
      _shareholders.removeAt(index);
    });
  }

  bool get isCODExpired {
    if (_codDeadline == null) return false;
    return DateTime.now().isAfter(_codDeadline!);
  }

  int get selectedShares => _shareholders.length;

  int get remainingShares =>
      _orderConfig == null ? 0 : _orderConfig!.remainingShares.floor();

  bool get _isShareLimitExceeded => selectedShares > remainingShares;

  // int get _remainingShares =>
  //     _orderConfig?.remainingShares ?? 0;

  // int get _sharesAfterSelection =>
  //     _remainingShares - selectedShares;

  // bool get _isShareLimitExceeded =>
  //     _sharesAfterSelection < 0;

  // Calculate total price: sum of animal prices + delivery fees
  double _calculateTotalPrice() {
    if (_pricing == null) return 0.0;

    final double pricePerShare =
        double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

    final int shareCount = _shareholders.length;

    final double lateFeeTotal = _lateFeePerShare * shareCount;

    double subtotal = (pricePerShare * shareCount) + lateFeeTotal;

    double deliveryFee = 0.0;
    if (_pricing!['delivery_type'] == 'paid') {
      deliveryFee =
          double.tryParse(_pricing!['delivery_fee'].toString()) ?? 0.0;
    }

    return subtotal + deliveryFee;
  }

  String _formatCodDeadline(DateTime date) {
    return "${date.day}/${date.month}/${date.year} "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  double get _lateFeePerShare {
    if (!isCODExpired) return 0.0;
    if (_orderConfig == null) return 0.0;

    return _orderConfig!.lateBookingFee;
  }

  Map<String, dynamic> _buildAddress(Shareholder s) {
    if (s.useSavedAddress && _savedAddress != null) {
      return {
        'country': _savedAddress!['country'],
        'country_iso': _savedAddress!['country_iso'],
        'state': _savedAddress!['state'],
        'city': _savedAddress!['city'],
        'postal_code': _savedAddress!['postal_code'],
        'address_line': _savedAddress!['address'],
      };
    }

    // User-entered address
    return {
      'country': s.selectedCountryName,
      'country_iso': s.countryISO,
      'state': s.selectedState?.name,
      'city': s.selectedCity?.name,
      'postal_code': s.postalCodeController.text.trim(),
      'address_line': s.addressController.text.trim(),
    };
  }

  // Get allowed payment methods from selected animals
  List<String> _getAllowedPaymentMethods() {
    final List<String> methods = [];

    if (_allowCOD) {
      methods.add('Cash');
    }

    if (_allowOnline) {
      methods.add('Online');
    }

    return methods;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConfig) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_orderConfig == null) {
      return const Scaffold(
        body: Center(child: Text("Order configuration unavailable")),
      );
    }

    if (!_paymentSettingsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // final currency = context.read<CurrencyNotifier>();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          "Order Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _savedAddressCard(),
                  _remainingSharesBanner(),

                  Text(
                    "Shareholder Information",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_remainingShares > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "You can add up to $_remainingShares shareholders",
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),

                  ...List.generate(
                    _shareholders.length,
                    (index) => _shareholderCard(index),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: remainingShares <= 0 ? null : _addShareholder,

                      icon: Icon(
                        Icons.add_circle_outline,
                        color: AppTheme.primaryGreen,
                      ),
                      label: Text(
                        "Add Another Shareholder",
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Payment Summary",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _paymentSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Align(alignment: Alignment.bottomCenter, child: _buildBottomBar()),
            if (_isLoading)
              Container(
                color: AppTheme.bgGradientEnd.withOpacity(0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  T? firstWhereOrNull<T>(List<T> list, bool Function(T) test) {
    for (final item in list) {
      if (test(item)) return item;
    }
    return null;
  }

  int get _sharesAfterSelection => remainingShares - _shareholders.length;

  Widget _remainingSharesBanner() {
    final remaining = remainingShares;
    final after = _sharesAfterSelection;

    final bool warning = after <= 3 && after >= 0;
    final bool error = after < 0;

    Color bgColor = AppTheme.primaryGreen.withOpacity(0.1);
    Color textColor = AppTheme.primaryGreen;
    IconData icon = Icons.check_circle;
    if (remaining <= 0) {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.red;
      icon = Icons.block;
    }

    if (warning) {
      bgColor = Colors.orange.withOpacity(0.15);
      textColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    }

    if (error) {
      bgColor = Colors.red.withOpacity(0.15);
      textColor = Colors.red;
      icon = Icons.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              remaining <= 0
                  ? "All shares are sold out."
                  : error
                  ? "Only $remaining shares available. Please remove extra shareholders."
                  : "Remaining shares: $after",

              style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareholderCard(int index) {
    // final currency = context.read<CurrencyNotifier>();
    final shareholder = _shareholders[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                radius: 18,
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_shareholders.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: AppTheme.warningRed,
                  ),
                  onPressed: () => _removeShareholder(index),
                ),
            ],
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.nameController,
            label: "Full Name of Shareholder",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 15),
          _customTextField(
            controller: shareholder.guardianController,
            label: "Father / Guardian Name",
            icon: Icons.family_restroom_outlined,
          ),
          const SizedBox(height: 15),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "Use saved address",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            value: shareholder.useSavedAddress,
            activeColor: AppTheme.primaryGreen,
            onChanged: _savedAddress == null
                ? null
                : (val) async {
                    if (val == true) {
                      final countryISO = _savedAddress!['country_iso'];

                      final states = await csc.getStatesOfCountry(countryISO);

                      final state = firstWhereOrNull<csc.State>(
                        states,
                        (s) =>
                            s.name.toLowerCase() ==
                            (_savedAddress!['state'] ?? '').toLowerCase(),
                      );

                      List<csc.City> cities = [];
                      csc.City? city;

                      if (state != null) {
                        cities = await csc.getStateCities(
                          state.countryCode,
                          state.isoCode,
                        );

                        city = firstWhereOrNull<csc.City>(
                          cities,
                          (c) =>
                              c.name.toLowerCase() ==
                              (_savedAddress!['city'] ?? '').toLowerCase(),
                        );
                      }

                      setState(() {
                        shareholder.useSavedAddress = true;

                        shareholder.selectedCountryName =
                            _savedAddress!['country'];
                        shareholder.countryISO = countryISO;

                        shareholder.states = states;
                        shareholder.selectedState = state;

                        shareholder.cities = cities;
                        shareholder.selectedCity = city;

                        shareholder.postalCodeController.text =
                            _savedAddress!['postal_code'] ?? '';
                        shareholder.addressController.text =
                            _savedAddress!['address'] ?? '';
                      });
                    } else {
                      setState(() {
                        shareholder.useSavedAddress = false;

                        shareholder.selectedCountryName = null;
                        shareholder.countryISO = null;
                        shareholder.selectedState = null;
                        shareholder.selectedCity = null;
                        shareholder.states = [];
                        shareholder.cities = [];

                        shareholder.addressController.clear();
                        shareholder.postalCodeController.clear();
                      });
                    }
                  },
          ),

          if (!shareholder.useSavedAddress) ...[
            InkWell(
              onTap: () {
                showCountryPicker(
                  context: context,
                  onSelect: (country) async {
                    setState(() {
                      shareholder.selectedCountryName = country.name;
                      shareholder.countryISO = country.countryCode;

                      shareholder.selectedState = null;
                      shareholder.selectedCity = null;
                      shareholder.states = [];
                      shareholder.cities = [];
                    });

                    shareholder.states = await csc.getStatesOfCountry(
                      country.countryCode,
                    );

                    if (mounted) setState(() {});
                  },
                );
              },
              child: AbsorbPointer(
                child: _customTextField(
                  controller: TextEditingController(
                    text: shareholder.selectedCountryName ?? '',
                  ),
                  label: "Country",
                  icon: Icons.public,
                ),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<csc.State>(
              value: shareholder.selectedState,
              isExpanded: true,
              items: shareholder.states
                  .map(
                    (s) => DropdownMenuItem<csc.State>(
                      value: s,
                      child: Text(s.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  shareholder.selectedState = value;
                  shareholder.selectedCity = null;
                  shareholder.cities = [];
                });

                if (value != null) {
                  shareholder.cities = await csc.getStateCities(
                    value.countryCode,
                    value.isoCode,
                  );
                  if (mounted) setState(() {});
                }
              },
              decoration: const InputDecoration(
                labelText: "State",
                prefixIcon: Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<csc.City>(
              value: shareholder.selectedCity,
              isExpanded: true,
              items: shareholder.cities
                  .map(
                    (c) => DropdownMenuItem<csc.City>(
                      value: c,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  shareholder.selectedCity = value;
                });
              },
              decoration: const InputDecoration(
                labelText: "City",
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 10),

            _customTextField(
              controller: shareholder.addressController,
              label: "Street / House Address",
              icon: Icons.home_outlined,
            ),

            const SizedBox(height: 10),

            _customTextField(
              controller: shareholder.postalCodeController,
              label: "Postal Code",
              icon: Icons.markunread_mailbox,
            ),
          ],
          Text(
            "Select Qurbani Day",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Day 1', 'Day 2', 'Day 3'].map((day) {
              bool isSelected = shareholder.qurbaniDay == day;
              return ChoiceChip(
                label: Text(day),
                selected: isSelected,
                selectedColor: AppTheme.primaryGreen,
                onSelected: (_) => setState(() => shareholder.qurbaniDay = day),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.bgGradientEnd : Colors.black,
                ),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _savedAddressCard() {
    if (_savedAddress == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Saved Address",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          _addressRow("Country", _savedAddress!['country']),
          _addressRow("State", _savedAddress!['state']),
          _addressRow("City", _savedAddress!['city']),
          _addressRow("Postal Code", _savedAddress!['postal_code']),
          _addressRow("Address", _savedAddress!['address']),
        ],
      ),
    );
  }

  Widget _addressRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _paymentSection() {
    if (_pricing == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Declare FIRST
    final int shareCount = _shareholders.length;

    final double pricePerShare =
        double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

    final double subtotal = pricePerShare * shareCount;

    final double lateFeeTotal = _lateFeePerShare * shareCount;

    double deliveryFee = 0.0;
    if (_pricing!['delivery_type'] == 'paid') {
      deliveryFee =
          double.tryParse(_pricing!['delivery_fee'].toString()) ?? 0.0;
    }

    final double totalBase = subtotal + deliveryFee + lateFeeTotal;

    final double convertedSubtotal = subtotal;
    final double convertedDelivery = deliveryFee;
    final double convertedTotal = totalBase;
    final double convertedLateFee = lateFeeTotal;

    final allowedMethods = _getAllowedPaymentMethods();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          ...allowedMethods.map((method) {
            final bool isCash = method == 'Cash';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioListTile<String>(
                  title: Text(isCash ? 'Cash' : 'Online Payment'),
                  value: method,
                  groupValue: _paymentMethod,
                  onChanged: (isCash && isCODExpired)
                      ? null
                      : (val) => setState(() => _paymentMethod = val!),
                  activeColor: AppTheme.primaryGreen,
                  contentPadding: EdgeInsets.zero,
                ),

                // ✅ Cash deadline info
                if (isCash && _codDeadline != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          isCODExpired ? Icons.cancel : Icons.access_time,
                          size: 14,
                          color: isCODExpired ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCODExpired
                              ? "Cash payment deadline has passed"
                              : "Pay cash before: ${_formatCodDeadline(_codDeadline!)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isCODExpired ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }).toList(),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgGradientStart.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _priceRow("Subtotal", convertedSubtotal, "₹"),
                _priceRow("Delivery Charges", convertedDelivery, "₹"),

                if (isCODExpired)
                  Container(
                    margin: const EdgeInsets.only(left: 16, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Late booking fee of ₹ "
                      "${_lateFeePerShare.toStringAsFixed(2)} "
                      "per share applied",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                // ✅ Late COD fee (only if applicable)
                if (lateFeeTotal > 0)
                  _priceRow("Late COD Fee", convertedLateFee, "₹"),

                const Divider(),
                _priceRow(
                  "Total Price",
                  convertedTotal,
                  "₹",
                  isBold: true,
                  fontSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    double amount,
    String currencySymbol, {
    bool isBold = false,
    double fontSize = 16,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          "$currencySymbol ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  // Widget _paymentOption(String title, String value, IconData icon) {
  //   return RadioListTile<String>(
  //     title: Text(
  //       title,
  //       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  //     ),
  //     secondary: Icon(icon, color: AppTheme.primaryGreen),
  //     value: value,
  //     groupValue: _paymentMethod,
  //     onChanged: (val) => setState(() => _paymentMethod = val!),
  //     activeColor: AppTheme.primaryGreen,
  //     contentPadding: EdgeInsets.zero,
  //   );
  // }

  Widget _customTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xffF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool noSharesLeft = remainingShares <= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: (_isLoading || _isShareLimitExceeded || noSharesLeft)
              ? null
              : _submitOrder,

          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            remainingShares <= 0
                ? "No Shares Available"
                : _isShareLimitExceeded
                ? "Too many shareholders"
                : "Confirm & Place Order",

            style: TextStyle(fontSize: 18, color: AppTheme.bgGradientEnd),
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder() async {
    final allowedMethods = _getAllowedPaymentMethods();

    if (_pricing == null) {
      Fluttertoast.showToast(
        msg: "Pricing not loaded",
        backgroundColor: AppTheme.warningRed,
      );
      return;
    }

    if (!allowedMethods.contains(_paymentMethod)) {
      Fluttertoast.showToast(
        msg: "Selected payment method is not allowed",
        backgroundColor: AppTheme.warningRed,
      );
      return;
    }

    if (_paymentMethod == 'Cash' && isCODExpired) {
      Fluttertoast.showToast(
        msg: "Cash deadline has passed",
        backgroundColor: Colors.red,
      );
      return;
    }

    // ✅ Validate shareholders
    for (var s in _shareholders) {
      // Basic required fields
      if (s.nameController.text.trim().isEmpty ||
          s.guardianController.text.trim().isEmpty ||
          s.addressController.text.trim().isEmpty) {
        Fluttertoast.showToast(
          msg: "Please fill all required fields",
          backgroundColor: AppTheme.warningRed,
        );
        return;
      }
      if (remainingShares <= 0) {
        Fluttertoast.showToast(
          msg: "No shares available",
          backgroundColor: Colors.red,
        );
        return;
      }

      // 🔐 Skip address validation when using saved address
      if (!s.useSavedAddress) {
        if (s.countryISO == null) {
          Fluttertoast.showToast(
            msg: "Please select a country",
            backgroundColor: AppTheme.warningRed,
          );
          return;
        }

        if (s.states.isNotEmpty && s.selectedState == null) {
          Fluttertoast.showToast(
            msg: "Please select a state",
            backgroundColor: AppTheme.warningRed,
          );
          return;
        }

        if (s.cities.isNotEmpty && s.selectedCity == null) {
          Fluttertoast.showToast(
            msg: "Please select a city",
            backgroundColor: AppTheme.warningRed,
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final double pricePerShare =
          double.tryParse(_pricing!['price_per_share'].toString()) ?? 0.0;

      // ✅ Shareholders payload (NO animals)
      final shareholdersData = _shareholders.map((s) {
        return {
          'name': s.nameController.text.trim(),
          'guardianName': s.guardianController.text.trim(),
          'qurbaniDay': s.qurbaniDay,

          'address': _buildAddress(s),

          'price': pricePerShare + _lateFeePerShare,
        };
      }).toList();

      final double baseTotal = _calculateTotalPrice();
      final double displayTotal = baseTotal;
      // Cash confirmation
      if (_paymentMethod == 'Cash') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Order"),
            content: Text(
              "Total: ₹ ${displayTotal.toStringAsFixed(2)}\n\n"
              "Place order with Cash?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        );

        if (confirm != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final String paymentStatus = _paymentMethod == 'Online'
          ? 'pending'
          : 'unpaid';

      final result = await OrderService.placeOrder(
        userId: '',
        adminId: widget.adminId,
        paymentMethod: _paymentMethod,
        shareholders: shareholdersData,
        totalAmount: baseTotal,
        paymentStatus: paymentStatus,
      );

      // ✅ Payment flow
      if (_paymentMethod == 'Online') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentProcessingPage(
              orderId: result['orderId'],
              totalAmount: baseTotal,
            ),
          ),
        );
      } else {
        Fluttertoast.showToast(
          msg: "Order placed successfully!",
          backgroundColor: AppTheme.accentGreen,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error: $e",
        backgroundColor: AppTheme.warningRed,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
