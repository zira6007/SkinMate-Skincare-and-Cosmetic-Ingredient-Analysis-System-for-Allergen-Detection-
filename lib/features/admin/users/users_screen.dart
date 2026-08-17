import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const Color _cream      = Color(0xFFF9F3EC);
  static const Color _softBrown  = Color(0xFFB07B6B);
  static const Color _darkBrown  = Color(0xFF4A2C2A);
  static const Color _lightPink  = Color(0xFFF5D5D5);
  static const Color _mutedBrown = Color(0xFF9A7070);

  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _supabase
          .from('USER')
          .select('userID, name, email, is_admin')
          .order('name');
      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleAdmin(String userId, bool current) async {
    // Prevent removing your own admin access
    final me = _supabase.auth.currentUser?.id;
    if (userId == me && current) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove your own admin access.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cream,
        title: Text(
          current ? 'Remove admin?' : 'Make admin?',
          style: const TextStyle(color: _darkBrown, fontSize: 16),
        ),
        content: Text(
          current
              ? 'This user will lose access to the admin panel.'
              : 'This user will gain full admin access.',
          style: const TextStyle(color: _mutedBrown, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _mutedBrown)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _softBrown,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase
          .from('USER')
          .update({'is_admin': !current})
          .eq('userID', userId);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(current ? 'Admin removed.' : 'Admin granted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cream,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
         // Header
Row(
  children: [
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Users',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _darkBrown,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Toggle admin access for registered SkinMate users.',
          style: TextStyle(
            fontSize: 13,
            color: _mutedBrown.withOpacity(0.8),
          ),
        ),
      ],
    ),
    const Spacer(),
    IconButton(
      onPressed: _loadUsers,
      icon: const Icon(Icons.refresh_rounded, color: _softBrown),
      tooltip: 'Refresh',
    ),
  ],
),
          const SizedBox(height: 16),

          // Table
         Expanded(
  child: _loading
      ? const Center(child: CircularProgressIndicator(color: _softBrown))
      : _error != null
          ? Center(child: Text('Error: $_error',
              style: const TextStyle(color: Colors.red)))
          : Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      columnSpacing: 40,
                      headingRowColor: WidgetStateProperty.all(_lightPink.withOpacity(0.5)),
                      columns: const [
                        DataColumn(label: Text('Name',  style: TextStyle(fontWeight: FontWeight.w700, color: _darkBrown))),
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.w700, color: _darkBrown))),
                        DataColumn(label: Text('Admin', style: TextStyle(fontWeight: FontWeight.w700, color: _darkBrown))),
                      ],
                      rows: _users.map((u) {
                        final isAdmin = u['is_admin'] == true;
                        final isMe = u['userID'] == _supabase.auth.currentUser?.id;
                        return DataRow(cells: [
                          DataCell(Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _softBrown.withOpacity(0.15),
                              child: Text(
                                (u['name'] as String? ?? '?')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 12, color: _softBrown, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(u['name'] ?? '-', style: const TextStyle(color: _darkBrown)),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _lightPink,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('You', style: TextStyle(fontSize: 10, color: _softBrown)),
                              ),
                            ],
                          ])),
                          DataCell(Text(u['email'] ?? '-', style: const TextStyle(color: _mutedBrown))),
                          DataCell(
                            Switch(
                              value: isAdmin,
                              activeColor: _softBrown,
                              onChanged: (_) => _toggleAdmin(u['userID'], isAdmin),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
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