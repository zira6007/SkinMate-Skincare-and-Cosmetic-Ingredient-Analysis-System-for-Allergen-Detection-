import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skin_mate/features/user/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:skin_mate/features/user/onboarding/quiz_screen.dart';
import 'package:skin_mate/features/user/onboarding/skin_profile_screen.dart';
import 'package:skin_mate/core/constants/app_colors.dart';

// ─── Supabase client shorthand ────────────────────────────────────────────────
final _supabase = Supabase.instance.client;

// ═══════════════════════════════════════════════════════════════════════════════
//  ProfileScreen
// ═══════════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _skinProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userRes = await _supabase
          .from('USER')
          .select()
          .eq('userID', userId)
          .maybeSingle();

      final skinRes = await _supabase
          .from('RESULT_SKIN_PROFILE')
          .select()
          .eq('userID', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? skinProfileWithConcerns = skinRes;
      if (skinRes != null) {
        final resultId = skinRes['resultID'] as String;
        final concernRows = await _supabase
            .from('SKIN_CONCERN')
            .select('concern_tag')
            .eq('resultID', resultId);

        final concerns = List<Map<String, dynamic>>.from(concernRows)
            .map((row) => row['concern_tag'] as String)
            .toList();

        skinProfileWithConcerns = {
          ...skinRes,
          'concerns': concerns,
        };
      }

      if (mounted) {
        setState(() {
          _user = userRes;
          _skinProfile = skinProfileWithConcerns;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────────
  String get _displayName => _user?['name'] ?? 'Unknown';
  String get _skinType =>
      _skinProfile?['skin_type'] ?? _user?['skin_type'] ?? 'Unknown skin type';

  void _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EditProfileScreen(user: _user ?? {})),
    );
    _loadData();
  }

  void _openSkinTypeQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuizScreen()),
    );
  }

  void _openSkinProfileSummary() {
    if (_skinProfile == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('No Skin Profile Yet',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
              'You haven\'t completed the skin quiz yet. '
              'Take the quiz to generate your skin profile.',
              style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.primaryMuted))),
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openSkinTypeQuiz();
                },
                child: const Text('Take Quiz',
                    style: TextStyle(color: AppColors.primary))),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkinProfileScreen(profile: _skinProfile!),
      ),
    );
  }

  void _openFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShareFeedbackScreen()),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Logout',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primaryMuted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _deleteAccount() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete Account',
          style: TextStyle(color: AppColors.textPrimary)),
      content: const Text(
          'Your account will be deactivated. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.primaryMuted))),
        TextButton(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.allergenColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
      ],
    ),
  );

  if (confirm == true) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _supabase.from('USER').update({
  'is_active': false,   // boolean now
  'deleted_at': DateTime.now().toIso8601String(),
}).eq('userID', userId);
    }
    await _supabase.auth.signOut();
   if (mounted) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
  }
}
  // ── build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildAvatarSection(),
          const SizedBox(height: 28),
          _buildMenuItem(
            icon: Icons.person_outline,
            label: 'Profile Details',
            onTap: _openEditProfile,
          ),
          _buildMenuItem(
            icon: Icons.assignment_outlined,
            label: 'Skin Type Quiz',
            onTap: _openSkinTypeQuiz,
          ),
          _buildMenuItem(
            icon: Icons.face_retouching_natural_outlined,
            label: 'Skin Profile Summary',
            onTap: _openSkinProfileSummary,
          ),
          _buildMenuItem(
            icon: Icons.star_outline,
            label: 'Share Your Feedback',
            onTap: _openFeedback,
          ),
          _buildMenuItem(
            icon: Icons.person_remove_outlined,
            label: 'Delete Account',
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final avatarUrl = _user?['avatar_url'] as String?;
    return Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.secondaryCard,
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person_outline,
                  size: 38, color: AppColors.primaryMuted)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          _displayName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _skinType,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.secondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.primaryMuted, size: 22),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EditProfileScreen
// ═══════════════════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _countryOtherCtrl;
  String? _gender;
  String? _country;
  bool _saving = false;

  // ── Avatar state ───────────────────────────────────────────────────────────
  File? _pickedImage;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];
  final List<String> _countries = [
    'Malaysia',
    'Singapore',
    'Indonesia',
    'Thailand',
    'Philippines',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u['name'] ?? '');
    _emailCtrl = TextEditingController(text: u['email'] ?? '');
    _countryOtherCtrl = TextEditingController();
    _gender = u['gender'] ?? 'Female';
    _avatarUrl = u['avatar_url'] as String?;

    final storedCountry = u['country'] as String?;
    if (storedCountry != null && _countries.contains(storedCountry)) {
      _country = storedCountry;
    } else if (storedCountry != null && storedCountry.isNotEmpty) {
      _country = 'Other';
      _countryOtherCtrl.text = storedCountry;
    } else {
      _country = 'Malaysia';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _countryOtherCtrl.dispose();
    super.dispose();
  }

  // ── Pick & upload avatar ───────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() {
      _pickedImage = File(picked.path);
      _uploadingAvatar = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final ext = picked.path.split('.').last.toLowerCase();
      final storagePath = 'avatar/$userId.$ext';
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      await _supabase.storage
          .from('avatar')
          .upload(
            storagePath,
            File(picked.path),
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );

      final publicUrl = _supabase.storage
          .from('avatar')
          .getPublicUrl(storagePath);

      final bustedUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('USER')
          .update({'avatar_url': bustedUrl}).eq('userID', userId);

      if (mounted) {
        setState(() {
          _avatarUrl = bustedUrl;
          _uploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.allergenColor,
          ),
        );
      }
    }
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  String get _effectiveCountry {
    if (_country == 'Other') {
      final custom = _countryOtherCtrl.text.trim();
      return custom.isNotEmpty ? custom : 'Other';
    }
    return _country ?? 'Malaysia';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'gender': _gender,
        'country': _effectiveCountry,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('USER').update(updates).eq('userID', userId);

      final newEmail = _emailCtrl.text.trim();
      if (newEmail.isNotEmpty &&
          newEmail != _supabase.auth.currentUser?.email) {
        await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.allergenColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar picker ──────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.secondaryCard,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!) as ImageProvider
                          : (_avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null),
                      child: (_pickedImage == null && _avatarUrl == null)
                          ? const Icon(Icons.person_outline,
                              size: 38, color: AppColors.primaryMuted)
                          : null,
                    ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!_uploadingAvatar)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: AppColors.surface),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tap to change photo',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryMuted,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Name ───────────────────────────────────────────────────────
            _label('Name'),
            _inputField(_nameCtrl, hint: 'Your name'),
            const SizedBox(height: 16),

            // ── Email ──────────────────────────────────────────────────────
            _label('Account email'),
            _inputField(_emailCtrl, hint: 'you@example.com'),
            const SizedBox(height: 16),

            // ── Change Password ────────────────────────────────────────────
            _label('Password'),
            GestureDetector(
              onTap: _openChangePassword,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Change Password',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.primaryMuted, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Gender ─────────────────────────────────────────────────────
            _label('Gender'),
            _dropdownField(
              value: _gender,
              items: _genders,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 16),

            // ── Country ────────────────────────────────────────────────────
            _label('Country'),
            _dropdownField(
              value: _country,
              items: _countries,
              onChanged: (v) => setState(() => _country = v),
            ),
            if (_country == 'Other') ...[
              const SizedBox(height: 10),
              _inputField(
                _countryOtherCtrl,
                hint: 'Please specify your country',
              ),
            ],
            const SizedBox(height: 32),

            // ── Save button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  disabledBackgroundColor: AppColors.primaryLight,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface))
                    : const Text('Save',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel)),
      );

  Widget _inputField(TextEditingController ctrl,
      {String hint = '', bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: AppColors.borderFocused, width: 1.5),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: AppColors.borderFocused, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ChangePasswordScreen
// ═══════════════════════════════════════════════════════════════════════════════
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _newVisible = false;
  bool _confirmVisible = false;
  bool _saving = false;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPw = _newPasswordCtrl.text;
    final confirmPw = _confirmPasswordCtrl.text;

    if (newPw.isEmpty || confirmPw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    if (newPw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (newPw != confirmPw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: AppColors.allergenColor),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPw));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.allergenColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your new password must be at least 6 characters.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _label('New Password'),
            _passwordField(
              controller: _newPasswordCtrl,
              hint: '••••••••••••',
              visible: _newVisible,
              onToggle: () =>
                  setState(() => _newVisible = !_newVisible),
            ),
            const SizedBox(height: 16),

            _label('Confirm New Password'),
            _passwordField(
              controller: _confirmPasswordCtrl,
              hint: '••••••••••••',
              visible: _confirmVisible,
              onToggle: () =>
                  setState(() => _confirmVisible = !_confirmVisible),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textWhite,
                  disabledBackgroundColor: AppColors.primaryLight,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface))
                    : const Text('Update Password',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textLabel)),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
              color: AppColors.borderFocused, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            visible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.primaryMuted,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ShareFeedbackScreen
// ═══════════════════════════════════════════════════════════════════════════════
class ShareFeedbackScreen extends StatefulWidget {
  const ShareFeedbackScreen({super.key});

  @override
  State<ShareFeedbackScreen> createState() => _ShareFeedbackScreenState();
}

class _ShareFeedbackScreenState extends State<ShareFeedbackScreen> {
  int _overallRating = 0;
  final Map<String, int> _categoryRatings = {
    'Is easy to use': 0,
    'Has the feature I want': 0,
    'Feels fast and responsive': 0,
    'Is reliable': 0,
  };

  String? _issueType;
  final TextEditingController _whatCtrl = TextEditingController();
  final TextEditingController _commentCtrl = TextEditingController();

  final List<String> _issueTypes = [
    'Wrong Ingredient Detected',
    'App Crash / Bug',
    'Incorrect Skin Recommendation',
    'Missing Feature',
    'Other',
  ];

  bool _sendingRating = false;
  bool _sendingIssue = false;

  @override
  void dispose() {
    _whatCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendRating() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please rate SkinMate')));
      return;
    }
    setState(() => _sendingRating = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('REPORT_FEEDBACK').insert({
        'userID': userId,
        'rate': _overallRating,
        'easy_to_use': _categoryRatings['Is easy to use'],
        'has_features': _categoryRatings['Has the feature I want'],
        'fast_responsive': _categoryRatings['Feels fast and responsive'],
        'is_reliable': _categoryRatings['Is reliable'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your rating!'),
            backgroundColor: AppColors.primary,
          ),
        );
        setState(() {
          _overallRating = 0;
          for (final k in _categoryRatings.keys) {
            _categoryRatings[k] = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.allergenColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingRating = false);
    }
  }

  Future<void> _sendIssue() async {
    if (_issueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an issue type')));
      return;
    }
    setState(() => _sendingIssue = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final comment =
          '${_whatCtrl.text.trim()}\n\n${_commentCtrl.text.trim()}'.trim();

      await _supabase.from('REPORT_FEEDBACK').insert({
        'userID': userId,
        'issue_tag': _issueType,
        'issues_comment': comment.isNotEmpty ? comment : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report sent'),
            backgroundColor: AppColors.primary,
          ),
        );
        setState(() {
          _issueType = null;
          _whatCtrl.clear();
          _commentCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.allergenColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingIssue = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text(
          'Share Feedback',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rate SkinMate',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'How would you rate your experience?',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: _buildStarRow(_overallRating, 34, (v) {
                      setState(() => _overallRating = v);
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  ..._categoryRatings.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            _buildStarRow(e.value, 18, (v) {
                              setState(() => _categoryRatings[e.key] = v);
                            }),
                          ],
                        ),
                      )),
                  const SizedBox(height: 4),
                  _sendButton(
                    label: 'Send Rating',
                    loading: _sendingRating,
                    onPressed: _sendRating,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report an Issue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Let us know what went wrong.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _issueType,
                    hint: const Text(
                      'Select issue type',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint),
                    ),
                    onChanged: (v) => setState(() => _issueType = v),
                    items: _issueTypes
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _whatCtrl,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'What should it have said? (optional)',
                      hintStyle: const TextStyle(
                          color: AppColors.textHint, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _commentCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Additional comments (optional)',
                      hintStyle: const TextStyle(
                          color: AppColors.textHint, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.border, width: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sendButton(
                    label: 'Send Report',
                    loading: _sendingIssue,
                    onPressed: _sendIssue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: child,
    );
  }

  Widget _sendButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textWhite,
          disabledBackgroundColor: AppColors.primaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.surface))
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }

  Widget _buildStarRow(int current, double size, ValueChanged<int> onTap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < current;
        return GestureDetector(
          onTap: () => onTap(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? AppColors.primary : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}