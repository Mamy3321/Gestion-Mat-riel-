import 'package:flutter/material.dart';

import '../api.dart';

class AdminNotificationCreateScreen extends StatefulWidget {
  const AdminNotificationCreateScreen({super.key});

  @override
  State<AdminNotificationCreateScreen> createState() =>
      _AdminNotificationCreateScreenState();
}

class _AdminNotificationCreateScreenState
    extends State<AdminNotificationCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  int? _selectedUserId;

  bool _loadingUsers = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final result = await Api.get('/users/');

      if (!mounted) return;

      if (result is List) {
        setState(() {
          _users = result
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
          _loadingUsers = false;
        });
      } else if (result is Map && result['results'] is List) {
        setState(() {
          _users = (result['results'] as List)
              .whereType<Map>()
              .map(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
          _loadingUsers = false;
        });
      } else {
        setState(() {
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingUsers = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger les utilisateurs : $e',
          ),
        ),
      );
    }
  }

  String _userLabel(Map<String, dynamic> user) {
    final name = user['nom_complet']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final username = user['username']?.toString().trim();

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return user['email']?.toString() ?? 'Utilisateur';
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Veuillez sélectionner un utilisateur.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await Api.post(
        '/notifications/',
        {
          'utilisateur': _selectedUserId,
          'titre': _titleController.text.trim(),
          'message': _messageController.text.trim(),
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notification envoyée avec succès.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur : $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter une notification'),
      ),
      body: SafeArea(
        child: _loadingUsers
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      size: 52,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Nouvelle notification',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<int>(
                      initialValue: _selectedUserId,
                      decoration: const InputDecoration(
                        labelText: 'Destinataire',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: _users.map((user) {
                        final id = user['id'];

                        if (id is! int) {
                          return null;
                        }

                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            _userLabel(user),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).whereType<DropdownMenuItem<int>>().toList(),
                      onChanged: _sending
                          ? null
                          : (value) {
                              setState(() {
                                _selectedUserId = value;
                              });
                            },
                      validator: (value) {
                        if (value == null) {
                          return 'Sélectionnez un utilisateur.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _titleController,
                      enabled: !_sending,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        prefixIcon: Icon(
                          Icons.title_rounded,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Le titre est obligatoire.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _messageController,
                      enabled: !_sending,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 90),
                          child: Icon(
                            Icons.message_outlined,
                          ),
                        ),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Le message est obligatoire.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                              ),
                        label: Text(
                          _sending
                              ? 'Envoi...'
                              : 'Envoyer la notification',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}