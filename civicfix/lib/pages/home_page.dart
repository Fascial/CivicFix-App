import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  List<DocumentSnapshot> _issues = [];

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

    Query query = FirebaseFirestore.instance
        .collection('issues')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (loadMore && _lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        if (loadMore) {
          _issues.addAll(snapshot.docs);
        } else {
          _issues = snapshot.docs;
        }
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _limit;
      });
    } else {
      setState(() {
        _hasMore = false;
      });
    }
    setState(() {
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
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('CivicFix', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (_hasMore &&
              !_isLoadingMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            _fetchIssues(loadMore: true);
          }
          return false;
        },
        child: _issues.isEmpty
            ? const Center(
                child: Text('No issues found.', style: TextStyle(color: Colors.white70)),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _issues.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  try {
                    final data = _issues[index].data() as Map<String, dynamic>;
                    final imageUrl = data['imageUrl']?.toString();
                    final caption = data['caption']?.toString() ?? '';
                    final createdAt = data['createdAt'];
                    final location = data['location'] is Map ? data['location'] as Map<String, dynamic> : null;
                    final lat = location?['lat'] is num ? (location?['lat'] as num).toDouble() : null;
                    final long = location?['long'] is num ? (location?['long'] as num).toDouble() : null;

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
                                Text(
                                  caption,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
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