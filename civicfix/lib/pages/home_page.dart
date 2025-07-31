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
  final int _limit = 10;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _allIssues = [];

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  Future<void> _fetchIssues({bool loadMore = false}) async {
    if (_isLoadingMore || (!_hasMore && loadMore)) return;
    setState(() {
      _isLoadingMore = true;
    });

    Query issuesQuery = FirebaseFirestore.instance
        .collection('issues')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    Query inProgressQuery = FirebaseFirestore.instance
        .collection('in_progress_issues')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (loadMore && _lastDocument != null) {
      issuesQuery = issuesQuery.startAfterDocument(_lastDocument!);
      inProgressQuery = inProgressQuery.startAfterDocument(_lastDocument!);
    }

    final issuesSnapshot = await issuesQuery.get();
    final inProgressSnapshot = await inProgressQuery.get();

    List<Map<String, dynamic>> combined = [
      ...issuesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['status'] = data['status'] ?? 'Open';
        data['department_assigned'] = data['department_assigned'] ?? 'Unassigned';
        return data;
      }),
      ...inProgressSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['status'] = data['status'] ?? 'In Progress';
        data['department_assigned'] = data['department_assigned'] ?? 'Unassigned';
        return data;
      }),
    ];

    combined.sort((a, b) {
      final aTime = a['createdAt'] is Timestamp
          ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
          : 0;
      final bTime = b['createdAt'] is Timestamp
          ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
          : 0;
      return bTime.compareTo(aTime);
    });

    setState(() {
      if (loadMore) {
        _allIssues.addAll(combined);
      } else {
        _allIssues = combined;
      }
      _hasMore = issuesSnapshot.docs.length == _limit || inProgressSnapshot.docs.length == _limit;
      _isLoadingMore = false;
    });
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('MMM d, yyyy h:mm a').format(date);
      }
      if (timestamp is DateTime) {
        return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
      }
      return '';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the map.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (_hasMore &&
              !_isLoadingMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _fetchIssues(loadMore: true);
          }
          return false;
        },
        child: _allIssues.isEmpty
            ? const Center(
                child: Text('No issues found.', style: TextStyle(color: Colors.white70)),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _allIssues.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  try {
                    final data = _allIssues[index];
                    final imageUrl = data['imageUrl']?.toString();
                    final caption = data['caption']?.toString() ?? '';
                    final createdAt = data['createdAt'];
                    final location = data['location'] is Map ? data['location'] as Map<String, dynamic> : null;
                    final lat = location?['lat'] is num ? (location?['lat'] as num).toDouble() : null;
                    final long = location?['long'] is num ? (location?['long'] as num).toDouble() : null;
                    final status = data['status']?.toString() ?? 'Unknown';
                    final department = data['department_assigned']?.toString() ?? 'Unassigned';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: 260,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    width: double.infinity,
                                    height: 260,
                                    color: Colors.grey[800],
                                    child: const Center(child: CircularProgressIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stack) => Container(
                                  width: double.infinity,
                                  height: 260,
                                  color: Colors.grey[800],
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 48)),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.white38, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimestamp(createdAt),
                                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                                    ),
                                    const Spacer(),
                                    if (lat != null && long != null)
                                      InkWell(
                                        onTap: () => _openMap(lat, long),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on, color: Colors.deepPurpleAccent, size: 20),
                                            const SizedBox(width: 4),
                                            Text(
                                              'View Location',
                                              style: TextStyle(
                                                color: Colors.deepPurpleAccent,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(
                                        status,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: status == 'Open'
                                          ? Colors.green
                                          : status == 'In Progress'
                                              ? Colors.orange
                                              : Colors.blueGrey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Department: $department',
                                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
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
                  } catch (e, stack) {
                    print('Error building issue card: $e');
                    print(stack);
                    return Container(
                      margin: const EdgeInsets.all(16),
                      color: Colors.red,
                      child: Text('Error displaying issue', style: TextStyle(color: Colors.white)),
                    );
                  }
                },
              ),
      ),
    );
  }
}