import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedStatus = 'Unresolved';

  String get _collectionName {
    switch (_selectedStatus) {
      case 'In Progress':
        return 'in_progress_issues';
      case 'Resolved':
        return 'completed_issues';
      default:
        return 'issues';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final date = timestamp is Timestamp
          ? timestamp.toDate()
          : (timestamp is DateTime ? timestamp : DateTime.now());
      return DateFormat('MMM d, yyyy h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  void _openMap(double? lat, double? long) async {
    if (lat == null || long == null) return;
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$long';
    try {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
    }
  }

  Widget _buildStatusChips() {
    final statuses = ['Unresolved', 'In Progress', 'Resolved'];
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 12, top: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedStatus = status;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurpleAccent
                      : Colors.grey[850],
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getIssueStream() {
    return FirebaseFirestore.instance
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _buildStatusChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getIssueStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Error loading data.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No issues found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final imageUrl = data['imageUrl']?.toString();
                    final caption = data['caption']?.toString() ?? '';
                    final createdAt = data['createdAt'];
                    final location = data['location'] as Map<String, dynamic>?;
                    final lat = location?['lat']?.toDouble();
                    final long = location?['long']?.toDouble();
                    final status = data['status']?.toString() ?? 'Unknown';
                    final department =
                        data['department_assigned']?.toString() ?? 'Unassigned';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[850]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      color: Colors.grey[900],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Colors.grey[900],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white38,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatTimestamp(createdAt),
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    Chip(
                                      label: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: status == 'Resolved'
                                          ? Colors.green
                                          : status == 'In Progress'
                                          ? Colors.orange
                                          : Colors.blueGrey,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (caption.isNotEmpty)
                                  Text(
                                    caption,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.apartment,
                                      size: 16,
                                      color: Colors.deepPurpleAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        department,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (lat != null && long != null)
                                      GestureDetector(
                                        onTap: () => _openMap(lat, long),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurpleAccent
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.location_pin,
                                                color: Colors.deepPurpleAccent,
                                                size: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Location',
                                                style: TextStyle(
                                                  color:
                                                      Colors.deepPurpleAccent,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
