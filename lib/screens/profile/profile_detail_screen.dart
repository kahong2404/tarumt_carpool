import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../repositories/user_repository.dart';
import '../../services/profile_service.dart';
import '../../utils/app_errors.dart';
import '../../utils/validators.dart';

import '../../widgets/error_list.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/danger_button.dart';
import '../../widgets/primary_text_field.dart';

import '../../widgets/profile/profile_info_card.dart';
import '../../widgets/profile/editable_avatar.dart';
import '../../widgets/profile/read_only_field.dart';

import '../../auth/login_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  static const brandBlue = Color(0xFF1E73FF);

  final _auth = FirebaseAuth.instance;
  final _repo = UserRepository();
  final _svc = ProfileService();

  final _phoneCtrl = TextEditingController();

  bool _editingPhone = false;
  bool _saving = false;
  bool _uploading = false;
  bool _loggingOut = false;
  bool _deleting = false;

  List<String> _errors = [];

  String get _uid => _auth.currentUser!.uid;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _setErrors(Object e) {
    setState(() => _errors = AppErrors.friendlyList(e));
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;

    setState(() {
      _errors = [];
      _uploading = true;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      await _svc.uploadProfileImage(File(picked.path));
    } catch (e) {
      _setErrors(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _savePhone() async {
    final errs = Validators.validateEditPhone(phone: _phoneCtrl.text);
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() {
      _errors = [];
      _saving = true;
    });

    try {
      await _svc.updatePhoneRaw(_phoneCtrl.text);
      if (mounted) setState(() => _editingPhone = false);
    } catch (e) {
      _setErrors(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() {
      _errors = [];
      _loggingOut = true;
    });

    try {
      await _svc.logout();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    } catch (e) {
      _setErrors(e);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    if (_deleting) return;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
            'This action cannot be undone.\n\n'
                'Your profile will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: Color(0xFFE53935)),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() {
      _errors = [];
      _deleting = true;
    });

    try {
      await _svc.deleteAccount();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    } catch (e) {
      _setErrors(e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: const Text('Profile'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _repo.streamUserDoc(_uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data == null) {
            return const Center(child: Text('Profile not found.'));
          }

          final data = snap.data!;
          final name = (data['name'] ?? '') as String;
          final role = (data['activeRole'] ?? '') as String;
          final email = (data['email'] ?? '') as String;
          final staffId = (data['staffId'] ?? '') as String;
          final phone = (data['phone'] ?? '') as String;
          final photoUrl = (data['photoUrl'] ?? '') as String;

          // keep controller synced when not editing
          if (!_editingPhone) _phoneCtrl.text = phone;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ===== header =====
                Column(
                  children: [
                    EditableAvatar(
                      photoUrl: photoUrl,
                      uploading: _uploading,
                      onTap: _pickAndUpload,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: brandBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: brandBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                ErrorList(_errors),
                if (_errors.isNotEmpty) const SizedBox(height: 12),

                // ===== card =====
                ProfileInfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Info',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),

                      ReadOnlyField(label: 'TARUMT Email', value: email),
                      const SizedBox(height: 12),

                      ReadOnlyField(label: 'Student / Staff ID', value: staffId),
                      const SizedBox(height: 12),

                      PrimaryTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        suffixIcon: IconButton(
                          icon: Icon(_editingPhone ? Icons.close : Icons.edit),
                          onPressed: () {
                            setState(() {
                              _errors = [];
                              _editingPhone = !_editingPhone;
                              if (!_editingPhone) _phoneCtrl.text = phone;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_editingPhone)
                        PrimaryButton(
                          text: 'Save Phone',
                          onPressed: _saving ? null : _savePhone,
                          loading: _saving,
                        ),

                      const SizedBox(height: 18),

                      PrimaryButton(
                        text: 'Logout',
                        onPressed: _loggingOut ? null : _logout,
                        loading: _loggingOut,
                      ),

                      const SizedBox(height: 12),

                      DangerButton(
                        text: 'Delete Account',
                        onPressed: _deleting ? null : _confirmAndDeleteAccount,
                        loading: _deleting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
