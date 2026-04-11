import 'package:Qurbani/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:Qurbani/screens/user/admin_profile.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:intl/intl.dart';

class AdminDirectoryPage extends StatefulWidget {
  const AdminDirectoryPage({super.key});

  static Future<List<dynamic>> Function()? mockFetchVerifiedAdmins;
  @override
  State<AdminDirectoryPage> createState() => _AdminDirectoryPageState();
}

class _AdminDirectoryPageState extends State<AdminDirectoryPage> {
  final Color parchmentBg = const Color(0xFFF6EFDF);
  final TextEditingController _searchController = TextEditingController();

  String searchText = '';
  late Future<List<dynamic>> _adminsFuture;
  String? selectedCountry = 'India';
  String? selectedState = 'Uttar Pradesh';
  String? selectedCity = 'Aligarh';

  @override
  void initState() {
    super.initState();
    _adminsFuture = fetchVerifiedAdmins();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadAdmins() async {
    final future = fetchVerifiedAdmins();
    setState(() {
      _adminsFuture = future;
    });
    await future;
  }

  /// Fetch verified admins
  Future<List<dynamic>> fetchVerifiedAdmins() async {
    if (AdminDirectoryPage.mockFetchVerifiedAdmins != null) {
      return AdminDirectoryPage.mockFetchVerifiedAdmins!();
    }

    try {
      final res = await ApiClient.get(ApiClient.uri('admins/verified'));

      if (res.statusCode != 200) {
        return [];
      }

      final decoded = ApiClient.decodeMap(
        res,
        fallbackMessage: 'No admins approved yet',
      );
      final admins = decoded['admins'];

      if (admins is List) {
        return admins;
      }
    } on ApiException {
      return [];
    } on FormatException {
      return [];
    } on Exception {
      return [];
    }

    return [];
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

  List<dynamic> _filteredAdmins(List<dynamic> admins) {
    final query = searchText.trim().toLowerCase();

    return admins.where((admin) {
      final haystack = [
        admin['name'],
        admin['city'],
        admin['state'],
        admin['country'],
        admin['address'],
      ].join(' ').toLowerCase();

      if (query.isNotEmpty && !haystack.contains(query)) {
        return false;
      }
      if (selectedCountry != null && admin['country'] != selectedCountry) {
        return false;
      }
      if (selectedState != null && admin['state'] != selectedState) {
        return false;
      }
      if (selectedCity != null && admin['city'] != selectedCity) {
        return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters {
    return searchText.trim().isNotEmpty ||
        selectedCountry != null ||
        selectedState != null ||
        selectedCity != null;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      searchText = '';
      selectedCountry = null;
      selectedState = null;
      selectedCity = null;
    });
  }

  int _crossAxisCountForWidth(double width) {
    if (width >= 1180) return 4;
    if (width >= 860) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  String _locationText(Map<String, dynamic> admin) {
    final locationParts = [
      if ((admin['city'] ?? '').toString().trim().isNotEmpty) admin['city'],
      if ((admin['state'] ?? '').toString().trim().isNotEmpty) admin['state'],
      if ((admin['country'] ?? '').toString().trim().isNotEmpty)
        admin['country'],
    ];

    return locationParts.isNotEmpty
        ? locationParts.join(', ')
        : 'Location not available';
  }

  String _selectedLocationLabel() {
    final selectedParts = [
      if (selectedCity != null) selectedCity,
      if (selectedState != null) selectedState,
      if (selectedCountry != null) selectedCountry,
    ];

    return selectedParts.isEmpty
        ? 'All verified locations'
        : selectedParts.join(', ');
  }

  String _availabilityText(Map<String, dynamic> admin) {
    final bool isClosed = admin['is_order_closed'] == 1;
    final rawDeadline = (admin['order_deadline'] ?? '').toString().trim();

    if (isClosed) {
      return 'Orders currently closed';
    }

    if (rawDeadline.isEmpty) {
      return 'Orders currently open';
    }

    final deadline = DateTime.tryParse(rawDeadline);
    if (deadline == null) {
      return 'Orders currently open';
    }

    return 'Open until ${DateFormat('d MMM, h:mm a').format(deadline)}';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'A';

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: parchmentBg,
      appBar: AppBar(
        title: const Text(
          "Verified Admins",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bgGradientEnd,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reloadAdmins,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.bgGradientEnd,
            ),
            tooltip: 'Refresh admins',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightBackgroundGradient,
        ),
        child: FutureBuilder<List<dynamic>>(
          future: _adminsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildStatePanel(
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load verified admins',
                subtitle: 'Pull to refresh or try again in a moment.',
                actionLabel: 'Try Again',
                onAction: _reloadAdmins,
                actionIcon: Icons.refresh_rounded,
              );
            }

            final admins = snapshot.data ?? [];
            final filteredAdmins = _filteredAdmins(admins);
            final openAdmins = admins.where((admin) {
              return admin['is_order_closed'] != 1;
            }).length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = _crossAxisCountForWidth(
                  constraints.maxWidth,
                );
                final mainAxisExtent = crossAxisCount == 1 ? 238.0 : 292.0;

                return RefreshIndicator(
                  onRefresh: _reloadAdmins,
                  color: AppTheme.primaryGreen,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildHeroSection(
                              totalAdmins: admins.length,
                              openAdmins: openAdmins,
                              visibleAdmins: filteredAdmins.length,
                            ),
                            _buildSearchHeader(),
                            _buildFilters(admins),
                            _buildResultsSummary(
                              totalAdmins: admins.length,
                              visibleAdmins: filteredAdmins.length,
                            ),
                          ],
                        ),
                      ),
                      if (admins.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildStatePanel(
                            icon: Icons.verified_user_rounded,
                            title: 'No verified admins yet',
                            subtitle:
                                'Approved admins will appear here once they are ready to accept orders.',
                            actionLabel: 'Refresh',
                            onAction: _reloadAdmins,
                            actionIcon: Icons.refresh_rounded,
                          ),
                        )
                      else if (filteredAdmins.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildStatePanel(
                            icon: Icons.search_off_rounded,
                            title: 'No admins match your filters',
                            subtitle:
                                'Try another search term or clear the location filters.',
                            actionLabel: 'Clear Filters',
                            onAction: _clearFilters,
                            actionIcon: Icons.restart_alt_rounded,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: mainAxisExtent,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildAdminGridCard(
                                Map<String, dynamic>.from(
                                  filteredAdmins[index],
                                ),
                              );
                            }, childCount: filteredAdmins.length),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          Text(
            'Loading verified admins...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
    IconData actionIcon = Icons.refresh_rounded,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required int totalAdmins,
    required int openAdmins,
    required int visibleAdmins,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryGreen, Color(0xFF7A9462)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trusted Qurbani Marketplace',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Browse approved admins near you and choose with confidence.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFFF3F7EC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildHeroMetric(
                icon: Icons.shield_rounded,
                label: 'Verified',
                value: '$totalAdmins',
              ),
              _buildHeroMetric(
                icon: Icons.schedule_rounded,
                label: 'Open Now',
                value: '$openAdmins',
              ),
              _buildHeroMetric(
                icon: Icons.grid_view_rounded,
                label: 'Showing',
                value: '$visibleAdmins',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroPill(
                icon: Icons.verified_rounded,
                label: 'Super-admin approved',
              ),
              _buildHeroPill(
                icon: Icons.location_on_outlined,
                label: _selectedLocationLabel(),
              ),
              if (searchText.trim().isNotEmpty)
                _buildHeroPill(
                  icon: Icons.search_rounded,
                  label: 'Search: "${searchText.trim()}"',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFFE5F0DB)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search verified admins',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search by name, city, or address to find the right admin faster.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name, city, or address',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchText.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchText = '';
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: parchmentBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(List<dynamic> admins) {
    final countries = _uniqueValues(admins, 'country');
    final safeCountry = countries.contains(selectedCountry)
        ? selectedCountry
        : null;
    final states = safeCountry == null
        ? <String>[]
        : _uniqueValues(admins, 'state', country: safeCountry);
    final safeState = states.contains(selectedState) ? selectedState : null;
    final cities = safeCountry == null || safeState == null
        ? <String>[]
        : _uniqueValues(admins, 'city', country: safeCountry, state: safeState);
    final safeCity = cities.contains(selectedCity) ? selectedCity : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.65)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter by location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
                if (_hasActiveFilters)
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wideLayout = constraints.maxWidth >= 720;

                if (wideLayout) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Country',
                          icon: Icons.public_rounded,
                          value: safeCountry,
                          items: countries,
                          hint: 'All countries',
                          onChanged: (value) {
                            setState(() {
                              selectedCountry = value;
                              selectedState = null;
                              selectedCity = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'State',
                          icon: Icons.map_rounded,
                          value: safeState,
                          items: states,
                          hint: 'All states',
                          enabled: safeCountry != null,
                          onChanged: (value) {
                            setState(() {
                              selectedState = value;
                              selectedCity = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdown(
                          label: 'City',
                          icon: Icons.location_city_rounded,
                          value: safeCity,
                          items: cities,
                          hint: 'All cities',
                          enabled: safeState != null,
                          onChanged: (value) {
                            setState(() {
                              selectedCity = value;
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildDropdown(
                      label: 'Country',
                      icon: Icons.public_rounded,
                      value: safeCountry,
                      items: countries,
                      hint: 'All countries',
                      onChanged: (value) {
                        setState(() {
                          selectedCountry = value;
                          selectedState = null;
                          selectedCity = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'State',
                      icon: Icons.map_rounded,
                      value: safeState,
                      items: states,
                      hint: 'All states',
                      enabled: safeCountry != null,
                      onChanged: (value) {
                        setState(() {
                          selectedState = value;
                          selectedCity = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: 'City',
                      icon: Icons.location_city_rounded,
                      value: safeCity,
                      items: cities,
                      hint: 'All cities',
                      enabled: safeState != null,
                      onChanged: (value) {
                        setState(() {
                          selectedCity = value;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
    bool enabled = true,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? parchmentBg.withOpacity(0.85) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _buildResultsSummary({
    required int totalAdmins,
    required int visibleAdmins,
  }) {
    final summaryText = _hasActiveFilters
        ? 'Showing $visibleAdmins of $totalAdmins verified admins'
        : '$totalAdmins verified admins available';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summaryText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedLocationLabel(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$visibleAdmins results',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminGridCard(Map<String, dynamic> admin) {
    final String name = (admin['name'] ?? 'Unknown Admin').toString();
    final String address = (admin['address'] ?? '').toString().trim();
    final String adminId = (admin['id'] ?? '').toString();
    final String? photoUrl = (admin['photo_url'] ?? '').toString().trim();
    final bool isClosed = admin['is_order_closed'] == 1;
    final String locationText = _locationText(admin);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminProfilePage(adminId: adminId),
            ),
          );
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildVerifiedBadge(),
                    const Spacer(),
                    _buildAvailabilityBadge(isClosed),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAdminAvatar(photoUrl, name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1C2A1F),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: AppTheme.accentGreen,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  locationText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: parchmentBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.schedule_rounded,
                        text: _availabilityText(admin),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildInfoRow(
                          icon: Icons.home_work_outlined,
                          text: address,
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminProfilePage(adminId: adminId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: AppTheme.bgGradientEnd,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDBF0E0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 15, color: AppTheme.primaryGreen),
          SizedBox(width: 6),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(bool isClosed) {
    final Color bgColor = isClosed
        ? Colors.red.withOpacity(0.12)
        : AppTheme.primaryGreen.withOpacity(0.12);
    final Color textColor = isClosed
        ? Colors.red.shade700
        : AppTheme.primaryGreen;
    final IconData icon = isClosed
        ? Icons.block_rounded
        : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            isClosed ? 'Closed' : 'Open',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAvatar(String? photoUrl, String name) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.16),
          width: 2,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F2E8), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ClipOval(
        child: hasPhoto
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(name),
              )
            : _buildAvatarFallback(name),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Center(
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String text,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.accentGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}
