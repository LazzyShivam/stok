import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String userId;
  final String? avatarUrl;
  final String name;
  final double size;
  final bool showStatus;
  final UserStatus? status;
  final bool isAgent;

  const UserAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    required this.name,
    this.size = 40,
    this.showStatus = false,
    this.status,
    this.isAgent = false,
  });

  Color get _statusColor {
    switch (status) {
      case UserStatus.online: return AppTheme.onlineColor;
      case UserStatus.away: return AppTheme.awayColor;
      default: return AppTheme.offlineColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = avatarUrl != null
        ? (avatarUrl!.startsWith('http') ? avatarUrl! : '${AppConfig.uploadUrl}$avatarUrl')
        : null;

    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAgent ? const Color(0xFF1A3A3A) : AppTheme.surfaceVariant,
          ),
          child: ClipOval(
            child: fullUrl != null
                ? CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildInitials(initials),
                    errorWidget: (_, __, ___) => _buildInitials(initials),
                  )
                : _buildInitials(initials),
          ),
        ),
        if (showStatus && status != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 1.5),
              ),
            ),
          ),
        if (isAgent)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.background, width: 1.5),
              ),
              child: Icon(Icons.auto_awesome, size: size * 0.18, color: Colors.black),
            ),
          ),
      ],
    );
  }

  Widget _buildInitials(String initials) {
    return Container(
      color: isAgent ? const Color(0xFF1A3A3A) : _colorForName(),
      child: Center(
        child: Text(
          isAgent ? '🤖' : initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
            color: isAgent ? AppTheme.secondary : Colors.white,
          ),
        ),
      ),
    );
  }

  Color _colorForName() {
    final colors = [
      const Color(0xFF6C63FF), const Color(0xFFFF6B9D), const Color(0xFF4ECDC4),
      const Color(0xFFFFD93D), const Color(0xFF95E1D3), const Color(0xFFF38181),
    ];
    return colors[userId.hashCode.abs() % colors.length];
  }
}
