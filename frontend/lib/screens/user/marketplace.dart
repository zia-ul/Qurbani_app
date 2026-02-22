import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:Qurbani/screens/user/admin_profile.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class AdminDirectoryPage extends StatefulWidget {
  const AdminDirectoryPage({super.key});

  static Future<List<dynamic>> Function()? mockFetchVerifiedAdmins;
  @override
  State<AdminDirectoryPage> createState() => _AdminDirectoryPageState();
}

class _AdminDirectoryPageState extends State<AdminDirectoryPage> {
  String searchText = '';
  late Future<List<dynamic>> _adminsFuture;

  final Color parchmentBg = const Color(0xffF2E8D5);
  static final String? _baseUrl = dotenv.env['BASE_URL'];
  String? selectedCountry;
  String? selectedState;
  String? selectedCity;

  @override
  void initState() {
    super.initState();
    _adminsFuture = fetchVerifiedAdmins();
  }

  /// Fetch verified admins
  Future<List<dynamic>> fetchVerifiedAdmins() async {
    if (AdminDirectoryPage.mockFetchVerifiedAdmins != null) {
      return AdminDirectoryPage.mockFetchVerifiedAdmins!();
    }

    final res = await http.get(Uri.parse("$_baseUrl/admins/verified"));

    if (res.statusCode != 200) {
      throw Exception("Failed to load admins");
    }

    return jsonDecode(res.body)['admins'];
  }

  List<String> _uniqueValues(
    List<dynamic> admins,
    String key, {
    String? country,
    String? state,
  }) {
    return admins
        .where((a) {
          if (country != null && a['country'] != country) return false;
          if (state != null && a['state'] != state) return false;
          return (a[key] ?? '').toString().isNotEmpty;
        })
        .map((a) => a[key].toString())
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: parchmentBg,
      appBar: AppBar(
        title: const Text(
          "Verified Qassab",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: const [
          // CartBadge(),
          SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              "Each city has one verified qassab to ensure quality, transparency, and proper Qurbani management.",
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkBgGradientStart,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          _buildSearchHeader(),
          _buildFilters(),

          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _adminsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final admins = snapshot.data ?? [];

                // Search filter
                final filteredAdmins = admins.where((admin) {
                  final name = (admin['name'] ?? '').toString().toLowerCase();

                  if (!name.contains(searchText.toLowerCase())) return false;
                  if (selectedCountry != null &&
                      admin['country'] != selectedCountry) {
                    return false;
                  }
                  if (selectedState != null &&
                      admin['state'] != selectedState) {
                    return false;
                  }
                  if (selectedCity != null && admin['city'] != selectedCity) {
                    return false;
                  }

                  return true;
                }).toList();

                if (filteredAdmins.isEmpty) {
                  return const Center(child: Text("No verified qassabs found"));
                }

                return GridView.builder(
                  key: ValueKey(searchText),
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.69,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredAdmins.length,
                  itemBuilder: (context, index) =>
                      _buildAdminGridCard(filteredAdmins[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return FutureBuilder<List<dynamic>>(
      future: _adminsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final admins = snapshot.data!;
        final List<String> countries = _uniqueValues(admins, 'country');
        final List<String> states = selectedCountry == null
            ? <String>[]
            : _uniqueValues(admins, 'state', country: selectedCountry);
        final List<String> cities =
            (selectedCountry == null || selectedState == null)
            ? <String>[]
            : _uniqueValues(
                admins,
                'city',
                country: selectedCountry,
                state: selectedState,
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              _buildDropdown(
                hint: "Country",
                value: selectedCountry,
                items: countries,
                onChanged: (v) {
                  setState(() {
                    selectedCountry = v;
                    selectedState = null;
                    selectedCity = null;
                  });
                },
              ),
              if (selectedCountry != null && states.isNotEmpty)
                _buildDropdown(
                  hint: "State",
                  value: selectedState,
                  items: states,
                  onChanged: (v) {
                    setState(() {
                      selectedState = v;
                      selectedCity = null;
                    });
                  },
                ),
              if (selectedState != null && cities.isNotEmpty)
                _buildDropdown(
                  hint: "City",
                  value: selectedCity,
                  items: cities,
                  onChanged: (v) {
                    setState(() {
                      selectedCity = v;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: parchmentBg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Search Bar
  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.bgGradientEnd,
      child: TextField(
        onChanged: (v) => setState(() => searchText = v),
        decoration: InputDecoration(
          hintText: "Search admins by name...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: parchmentBg.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// Admin Card (API data)
  Widget _buildAdminGridCard(Map<String, dynamic> admin) {
    final String name = admin['name'] ?? 'Unknown Admin';
    // final String address = admin['address'] ?? 'No Address';
    final String country = admin['country'] ?? '';
    final String state = admin['state'] ?? '';
    final String city = admin['city'] ?? '';
    final bool isClosed = admin['is_order_closed'] == 1;

    final String adminId = admin['id'];
    final String? photoUrl = admin['photo_url'];

    final List<String> locationParts = [
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (country.isNotEmpty) country,
    ];

    final String locationText = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : 'Location not available';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Icon(Icons.person, size: 35, color: AppTheme.primaryGreen)
                  : null,
            ),

            const SizedBox(height: 10),
            if (isClosed)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "CLOSED",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified, size: 14, color: Colors.blue),
              ],
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminProfilePage(adminId: adminId),
                    ),
                  );
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    AppTheme.primaryGreen,
                  ),
                  foregroundColor: WidgetStateProperty.all(
                    AppTheme.bgGradientEnd,
                  ), // text is white
                  overlayColor: WidgetStateProperty.all(
                    AppTheme.bgGradientEnd.withOpacity(0.1), // ripple effect
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                child: const Text(
                  "View Profile",
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
