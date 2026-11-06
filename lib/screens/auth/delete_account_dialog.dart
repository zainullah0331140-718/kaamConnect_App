import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class DeleteAccountDialog extends StatefulWidget {
  final bool isProvider;

  const DeleteAccountDialog({super.key, this.isProvider = false});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _deleting = true;
      _error = null;
    });

    final deleted = await Provider.of<AuthProvider>(context, listen: false)
        .deleteAccount(_passwordController.text);

    if (!mounted) return;

    if (deleted) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _deleting = false;
        _error = Provider.of<AuthProvider>(context, listen: false).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final red = Colors.red.shade700;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: red),
          const SizedBox(width: 8),
          const Text('Delete Account'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isProvider
                    ? 'This permanently deletes your KaamConnect account, business profile, services, advertisements, and uploaded photos. This action cannot be undone.'
                    : 'This permanently deletes your KaamConnect account, reviews, favorites, and complaints. This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: Colors.red.shade900),
              ),
              const SizedBox(height: 16),
              const Text(
                'Current Password',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter your password' : null,
              ),
              const SizedBox(height: 14),
              const Text(
                'Type DELETE to confirm',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirmController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  prefixIcon: Icon(Icons.delete_forever_outlined),
                ),
                validator: (val) =>
                    val?.trim().toUpperCase() != 'DELETE'
                        ? 'Type DELETE to confirm'
                        : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: red),
          onPressed: _deleting ? null : _submit,
          child: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete My Account'),
        ),
      ],
    );
  }
}
