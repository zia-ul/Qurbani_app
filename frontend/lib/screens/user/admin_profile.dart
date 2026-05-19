import 'package:Qurbani/services/api_client.dart';
import 'package:Qurbani/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:Qurbani/theme/theme.dart';
import 'package:Qurbani/screens/user/order_form.dart';
import 'package:intl/intl.dart';

class AdminProfilePage extends StatefulWidget {
  final String adminId;

  const AdminProfilePage({super.key, required this.adminId});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  bool isRateLoading = true;
  final Color primaryGreen = AppTheme.primaryGreen;
  final Color backgroundGrey = const Color(0xffF8F9FA);
  final _storage = const FlutterSecureStorage();
  late Future<Map<String, dynamic>> _adminFuture;

  @override
  void initState() {
    super.initState();
    _adminFuture = _fetchAdminProfile();
  }

  Future<Map<String, dynamic>> _fetchAdminProfile() async {
    AppLogger.debug("Fetching admin profile | adminId=${widget.adminId}");

    final token = await _storage.read(key: "token");
    if (token == null) {
      AppLogger.error("No auth token found while loading admin profile");
      throw Exception("No token found. User not logged in.");
    }

    try {
      final res = await ApiClient.get(
        ApiClient.uri('auth/adminprofile/${widget.adminId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('Admin profile API response: ${res.statusCode} ${res.body}');

      AppLogger.debug(
        "Admin profile API response | statusCode=${res.statusCode}",
      );

      if (res.statusCode == 200) {
        final data = ApiClient.decodeMap(
          res,
          fallbackMessage: 'Unable to load admin profile right now.',
        );

        AppLogger.info(
          "Admin profile loaded successfully | adminId=${widget.adminId}",
        );

        return data;
      } else {
        final message = ApiClient.errorMessage(
          res,
          fallbackMessage: 'Unable to load admin profile right now.',
        );
        AppLogger.error(
          "Failed to load admin profile | statusCode=${res.statusCode} | message=$message",
        );
        throw ApiException(message, statusCode: res.statusCode);
      }
    } catch (e, stack) {
      AppLogger.error(
        "Exception while fetching admin profile | adminId=${widget.adminId}",
        e,
        stack,
      );
      rethrow;
    }
  }

  void _showProfilePhoto(String photoUrl) {
    if (photoUrl.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(dialogContext),
              child: Container(
                color: Colors.transparent,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 96,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
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
      backgroundColor: backgroundGrey,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _adminFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            AppLogger.error(
              "Admin profile load failed | adminId=${widget.adminId}",
              snapshot.error,
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _friendlyErrorMessage(
                        snapshot.error,
                        fallback: 'Unable to load admin profile right now.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _adminFuture = _fetchAdminProfile();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: AppTheme.bgGradientEnd,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final response = snapshot.data!;
final data = response['admin'] ?? {};

          final String name = data['name'] ?? 'Unknown Admin';
          final String description = data['description'] ?? 'Not Available';
          final String phone = data['phone'] ?? 'N/A';
          final String address = data['address'] ?? 'N/A';
          final String photoUrl = (data['photo_url'] ?? '').toString().trim();

          final double avgRating = data['averageRating'] is num
              ? (data['averageRating'] as num).toDouble()
              : double.tryParse(data['averageRating']?.toString() ?? '') ?? 0;
          final int totalRatings = data['totalRatings'] is num
              ? (data['totalRatings'] as num).toInt()
              : int.tryParse(data['totalRatings']?.toString() ?? '') ?? 0;
          final int totalOrders = data['totalOrders'] is num
              ? (data['totalOrders'] as num).toInt()
              : int.tryParse(data['totalOrders']?.toString() ?? '') ?? 0;
          final int completedOrders = data['completedOrders'] is num
              ? (data['completedOrders'] as num).toInt()
              : int.tryParse(data['completedOrders']?.toString() ?? '') ?? 0;
          DateTime? orderDeadline;

          if (data['order_deadline'] != null) {
            orderDeadline = DateTime.tryParse(data['order_deadline']);
          }
          final bool isDeadlinePassed =
              orderDeadline != null && DateTime.now().isAfter(orderDeadline);

          return CustomScrollView(
            slivers: [
              // 1. Header with Gradient and Profile Image
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryGreen, primaryGreen.withOpacity(0.7)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: const BackButton(
                          color: AppTheme.bgGradientEnd,
                        ),
                        title: const Text(
                          "Admin Profile",
                          style: TextStyle(color: AppTheme.bgGradientEnd),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 110,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.bgGradientEnd,
                          shape: BoxShape.circle,
                        ),
                        child: GestureDetector(
                          onTap: () => _showProfilePhoto(photoUrl),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            child: ClipOval(
                              child: photoUrl.isNotEmpty
                                  ? Image.network(
                                      photoUrl,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person, size: 60),
                                    )
                                  : const Icon(Icons.person, size: 60),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 70)),

              // 2. Admin Name & Verification
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          "Verified Admin",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.star, color: Colors.orange[400], size: 18),
                        Text(
                          " ${avgRating.toStringAsFixed(1)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          totalRatings == 1
                              ? "(1 rating)"
                              : "($totalRatings ratings)",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    Text(description, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),

              // 3. Information Cards
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildInfoCard(
                      title: "Contact Information",
                      icon: Icons.contact_page,
                      children: [
                        _infoTile(Icons.phone, "Phone", phone),
                        _infoTile(Icons.location_on, "Address", address),
                        if (orderDeadline != null)
                          Text(
                            "Order Deadline: ${DateFormat('dd MMM yyyy').format(orderDeadline)}",
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Map Section
                    // _buildInfoCard(
                    //   title: "Operating Location",
                    //   icon: Icons.map,
                    //   children: [
                    //     ClipRRect(
                    //       borderRadius: BorderRadius.circular(12),
                    //       child: Stack(
                    //         alignment: Alignment.center,
                    //         children: [
                    // Image.network(
                    //   "https://maps.googleapis.com/maps/api/staticmap?center=$city&zoom=13&size=600x300&key=YOUR_KEY_HERE",
                    //   height: 150,
                    //   width: double.infinity,
                    //   fit: BoxFit.cover,
                    //   errorBuilder: (c, e, s) => Container(
                    //     height: 150,
                    //     color: Colors.grey[300],
                    //     child: const Icon(
                    //       Icons.map_outlined,
                    //       size: 50,
                    //       color: Colors.grey,
                    //     ),
                    //   ),
                    // ),
                    //           Container(
                    //             padding: const EdgeInsets.symmetric(
                    //               horizontal: 12,
                    //               vertical: 6,
                    //             ),
                    //             decoration: BoxDecoration(
                    //               color: AppTheme.bgGradientEnd,
                    //               borderRadius: BorderRadius.circular(20),
                    //               boxShadow: const [
                    //                 BoxShadow(
                    //                   color: Colors.black26,
                    //                   blurRadius: 4,
                    //                 ),
                    //               ],
                    //             ),
                    //             child: Text(
                    //               "$city Admin",
                    //               style: const TextStyle(
                    //                 fontWeight: FontWeight.bold,
                    //               ),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 24),

                    _adminOrderStatsRow(totalOrders, completedOrders),

                    const SizedBox(height: 24),

                    Column(
                      children: [
                        SizedBox(
                          width: 160,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isDeadlinePassed
                                ? null // ❌ disables button
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QurbaniOrderPage(
                                          adminId: widget.adminId,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDeadlinePassed
                                  ? Colors.grey
                                  : AppTheme.primaryGreen,
                            ),
                            child: const Text(
                              "Place Order",
                              style: TextStyle(
                                color: AppTheme.bgGradientEnd,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        if (isDeadlinePassed) ...[
                          const SizedBox(height: 6),
                          const Text(
                            "No more orders accepting",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.warningRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _adminOrderStatsRow(int totalOrders, int completedOrders) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgGradientEnd,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            icon: Icons.receipt_long,
            label: "Orders Received",
            value: totalOrders.toString(),
            color: AppTheme.primaryGreen,
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _statItem(
            icon: Icons.check_circle,
            label: "Completed",
            value: completedOrders.toString(),
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  String _friendlyErrorMessage(Object? error, {required String fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    final cleaned = error
        ?.toString()
        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '')
        .trim();

    if (cleaned == null || cleaned.isEmpty) {
      return fallback;
    }

    return cleaned;
  }
}
