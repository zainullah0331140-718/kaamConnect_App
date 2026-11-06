import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../widgets/app_logo.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth/change_password_dialog.dart';
import 'auth/delete_account_dialog.dart';
import 'login_screen.dart';
import 'provider_dashboard_screen.dart';
import 'register_screen.dart';
import 'server_config_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkTheme;

  const ProfileScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkTheme,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();
  bool _uploadingImage = false;

  Future<void> _pickAndUploadProfileImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null || !mounted) return;

      setState(() => _uploadingImage = true);

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isProvider = auth.user?.isProvider == true;
      await _api.uploadFile(
        isProvider ? '/providers/me/image' : '/users/me/image',
        fileField: 'file',
        file: file,
      );
      await auth.fetchCurrentUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update profile picture: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // User Header or Guest Prompt
            if (auth.isAuthenticated && user != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _uploadingImage ? null : _pickAndUploadProfileImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppConstants.primaryColor,
                              backgroundImage: user.profileImage != null &&
                                      user.profileImage!.isNotEmpty
                                  ? NetworkImage(
                                      _api.getMediaUrl(user.profileImage))
                                  : null,
                              child: user.profileImage == null ||
                                      user.profileImage!.isEmpty
                                  ? Text(
                                      user.fullName.isNotEmpty
                                          ? user.fullName
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 2,
                                  ),
                                ),
                                child: _uploadingImage
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppConstants.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // If Admin, show Admin Management Console
              if (user.isAdmin) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.purple.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple),
                    title: const Text(
                      'Admin Control Panel',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                    subtitle: const Text('Approve providers, moderate ads, categories & reviews'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.purple),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // If Provider or Admin, show Provider Dashboard quick link
              if (user.isProvider || user.isAdmin) ...[
                const SizedBox(height: 12),
                Card(
                  color: AppConstants.primaryColor.withOpacity(0.08),
                  child: ListTile(
                    leading: const Icon(Icons.storefront_rounded,
                        color: AppConstants.primaryColor),
                    title: const Text(
                      'Provider Business Portal',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Profile photo, 5 work images, ads & services'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProviderDashboardScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else ...[
              // Guest Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const AppLogo(
                        size: 64,
                        borderRadius: 16,
                        showBorder: true,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Welcome to KaamConnect',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to book services, write reviews, or register your professional business.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                              child: const Text('Log In'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: const Text('Register'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Settings & Preferences
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dns_rounded),
                    title: const Text('Backend API Server'),
                    subtitle: Text(
                      ApiClient().baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ServerConfigDialog(),
                      );
                    },
                  ),
                  if (auth.isAuthenticated) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_rounded),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => const ChangePasswordDialog(),
                        );
                        if (changed == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password changed successfully!')),
                          );
                        }
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: Icon(widget.isDarkTheme
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded),
                    title: const Text('Dark Mode'),
                    value: widget.isDarkTheme,
                    onChanged: (_) => widget.onToggleTheme(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About KaamConnect'),
                    subtitle: const Text('v1.0.0 (Flutter Multiplatform)'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'KaamConnect',
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Connecting You to Trusted Local Services across Pakistan.\nBuilt with Flutter & FastAPI.',
                        children: const [
                          SizedBox(height: 12),
                          Text(
                            'Supported Platforms: Android, iOS, Windows PC, macOS, Linux, and Web.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            if (auth.isAuthenticated) ...[
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Log Out'),
                        content: const Text(
                            'Are you sure you want to log out of KaamConnect?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Log Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await auth.logout();
                      if (context.mounted) {
                        Provider.of<FavoritesProvider>(context, listen: false).clearOnLogout();
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: Colors.red.shade700),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    user?.isProvider == true
                        ? 'Permanently remove your business, services, ads and photos'
                        : 'Permanently remove your account and personal data',
                  ),
                  onTap: () async {
                    final deleted = await showDialog<bool>(
                      context: context,
                      builder: (_) => DeleteAccountDialog(
                        isProvider: user?.isProvider == true,
                      ),
                    );
                    if (deleted == true && context.mounted) {
                      await Provider.of<FavoritesProvider>(context,
                              listen: false)
                          .clearOnLogout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Your account has been deleted.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
