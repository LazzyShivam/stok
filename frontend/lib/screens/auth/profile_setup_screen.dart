import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../providers/chat_provider.dart';
import '../../theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _avatar;
  bool _loading = false;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) setState(() => _avatar = File(file.path));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    await auth.updateProfile(name: name, bio: _bioController.text.trim());

    if (_avatar != null) {
      final api = context.read<ApiService>();
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(_avatar!.path),
      });
      await api.postForm('/users/me/avatar', formData);
    }

    setState(() => _loading = false);
    if (!mounted) return;
    await context.read<ChatProvider>().loadConversations();
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Set Up Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add your name and photo',
                style: TextStyle(color: AppTheme.onSurfaceMuted, fontSize: 15),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.surfaceVariant,
                      backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                      child: _avatar == null
                          ? const Icon(Icons.person_rounded, size: 56, color: AppTheme.onSurfaceMuted)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio (optional)',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                maxLines: 2,
                maxLength: 200,
              ),
              const Spacer(),
              _loading
                  ? const CircularProgressIndicator(color: AppTheme.primary)
                  : ElevatedButton(
                      onPressed: _save,
                      child: const Text('Get Started'),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
