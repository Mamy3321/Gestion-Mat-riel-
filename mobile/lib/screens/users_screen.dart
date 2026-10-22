import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];

  bool _loading = true;

  int? get _currentUserId {
    final value = Api.user?['id'];

    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  bool get _isAdmin {
    final role = Api.user?['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    return role == 'admin';
  }

  @override
  void initState() {
    super.initState();

    if (_isAdmin) {
      _loadUsers();
    } else {
      _loading = false;
    }
  }

  // ==========================================================
  // CHARGER LES UTILISATEURS
  // ==========================================================

  Future<void> _loadUsers() async {
    // Sécurité côté Flutter :
    // un utilisateur non-admin ne fait même pas la requête.
    if (!_isAdmin) {
      if (mounted) {
        setState(() {
          _users = [];
          _loading = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await Api.get('/users/');

      if (!mounted) return;

      List<Map<String, dynamic>> users = [];

      if (result is List) {
        users = result
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      } else if (result is Map && result['results'] is List) {
        users = (result['results'] as List)
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      // 403 : aucune alerte.
      // Normalement impossible car les non-admins
      // ne font même pas la requête.
      if (e.toString().contains('403')) {
        return;
      }

      toast(
        context,
        'Erreur lors du chargement des utilisateurs.',
      );
    }
  }

  // ==========================================================
  // APPROUVER
  // ==========================================================

  Future<void> _approve(Map<String, dynamic> user) async {
    if (!_isAdmin) return;

    final id = user['id'];

    if (id == null) return;

    try {
      await Api.post(
        '/users/$id/approve/',
        {},
      );

      if (!mounted) return;

      toast(
        context,
        'Compte validé avec succès.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('403')) {
        return;
      }

      toast(
        context,
        'Impossible de valider ce compte.',
      );
    }
  }

  // ==========================================================
  // REFUSER
  // ==========================================================

  Future<void> _reject(Map<String, dynamic> user) async {
    if (!_isAdmin) return;

    final id = user['id'];

    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Refuser le compte'),
          content: Text(
            'Voulez-vous vraiment refuser le compte de '
            '${_displayName(user)} ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Refuser'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await Api.post(
        '/users/$id/reject/',
        {},
      );

      if (!mounted) return;

      toast(
        context,
        'Compte refusé.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('403')) {
        return;
      }

      toast(
        context,
        'Impossible de refuser ce compte.',
      );
    }
  }

  // ==========================================================
  // SUPPRIMER
  // ==========================================================

  Future<void> _delete(Map<String, dynamic> user) async {
    if (!_isAdmin) return;

    final id = user['id'];

    if (id == null) return;

    final userId = int.tryParse(id.toString());

    // L'admin ne peut pas supprimer son propre compte
    if (userId != null && userId == _currentUserId) {
      toast(
        context,
        'Vous ne pouvez pas supprimer votre propre compte.',
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer le compte'),
          content: Text(
            'Voulez-vous vraiment supprimer le compte de '
            '${_displayName(user)} ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await Api.delete(
        '/users/$id/',
      );

      if (!mounted) return;

      toast(
        context,
        'Compte supprimé avec succès.',
      );

      await _loadUsers();
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('403')) {
        return;
      }

      toast(
        context,
        'Impossible de supprimer ce compte.',
      );
    }
  }

  // ==========================================================
  // MODIFIER
  // ==========================================================

  Future<void> _edit(Map<String, dynamic> user) async {
    if (!_isAdmin) return;

    final id = user['id'];

    if (id == null) return;

    final firstNameController = TextEditingController(
      text: user['first_name']?.toString() ?? '',
    );

    final lastNameController = TextEditingController(
      text: user['last_name']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: user['email']?.toString() ?? '',
    );

    String role =
        user['role']?.toString().toLowerCase() ?? 'utilisateur';

    if (![
      'admin',
      'equipe',
      'utilisateur',
    ].contains(role)) {
      role = 'utilisateur';
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Modifier le compte'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: firstNameController,
                        textCapitalization:
                            TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Prénom',
                          prefixIcon: Icon(
                            Icons.person_outline,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Le prénom est obligatoire';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: lastNameController,
                        textCapitalization:
                            TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Le nom est obligatoire';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: emailController,
                        keyboardType:
                            TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                          ),
                        ),
                        validator: (value) {
                          final email =
                              value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'L’email est obligatoire';
                          }

                          final regex = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );

                          if (!regex.hasMatch(email)) {
                            return 'Email invalide';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(
                          labelText: 'Type de compte',
                          prefixIcon: Icon(
                            Icons.manage_accounts_outlined,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(
                              'Administrateur',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'equipe',
                            child: Text(
                              'Équipe',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'utilisateur',
                            child: Text(
                              'Utilisateur simple',
                            ),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }

                                setDialogState(() {
                                  role = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            false,
                          );
                        },
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            await Api.patch(
                              '/users/$id/',
                              {
                                'first_name':
                                    firstNameController
                                        .text
                                        .trim(),
                                'last_name':
                                    lastNameController
                                        .text
                                        .trim(),
                                'email':
                                    emailController
                                        .text
                                        .trim()
                                        .toLowerCase(),
                                'role': role,
                              },
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(
                              dialogContext,
                              true,
                            );
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            if (e.toString().contains('403')) {
                              return;
                            }

                            if (!dialogContext.mounted) {
                              return;
                            }

                            toast(
                              dialogContext,
                              'Impossible de modifier ce compte.',
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();

    if (result == true && mounted) {
      toast(
        context,
        'Compte modifié avec succès.',
      );

      await _loadUsers();
    }
  }

  // ==========================================================
  // NOM AFFICHÉ
  // ==========================================================

  String _displayName(Map<String, dynamic> user) {
    final nomComplet =
        user['nom_complet']?.toString().trim() ?? '';

    if (nomComplet.isNotEmpty) {
      return nomComplet;
    }

    final firstName =
        user['first_name']?.toString().trim() ?? '';

    final lastName =
        user['last_name']?.toString().trim() ?? '';

    final fullName =
        '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final email =
        user['email']?.toString().trim() ?? '';

    if (email.isNotEmpty) {
      return email;
    }

    return 'Utilisateur';
  }

  // ==========================================================
  // LABEL ROLE
  // ==========================================================

  String _roleLabel(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return 'Administrateur';

      case 'equipe':
        return 'Équipe';

      case 'utilisateur':
        return 'Utilisateur simple';

      case 'technicien':
        return 'Équipe';

      case 'realisateur':
        return 'Utilisateur simple';

      default:
        return 'Utilisateur';
    }
  }

  // ==========================================================
  // LABEL VALIDATION
  // ==========================================================

  String _validationLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return 'Validé';

      case 'pending':
        return 'En attente';

      case 'rejected':
        return 'Refusé';

      default:
        return 'Inconnu';
    }
  }

  // ==========================================================
  // COULEUR VALIDATION
  // ==========================================================

  Color _validationColor(
    BuildContext context,
    String? status,
  ) {
    final scheme = Theme.of(context).colorScheme;

    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;

      case 'pending':
        return Colors.orange;

      case 'rejected':
        return scheme.error;

      default:
        return scheme.outline;
    }
  }

  // ==========================================================
  // CARTE UTILISATEUR
  // ==========================================================

  Widget _buildUserCard(
    BuildContext context,
    Map<String, dynamic> user,
  ) {
    final id = int.tryParse(
      user['id']?.toString() ?? '',
    );

    final isCurrentUser =
        id != null && id == _currentUserId;

    final role =
        user['role']?.toString().toLowerCase();

    final validationStatus =
        user['validation_status']
            ?.toString()
            .toLowerCase();

    final isActive =
        user['is_active'] == true;

    final photo =
        user['photo']?.toString();

    final name = _displayName(user);

    final email =
        user['email']?.toString().trim() ?? '';

    final initials = _initials(user);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      photo != null &&
                              photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                  child:
                      photo == null ||
                              photo.isEmpty
                          ? Text(
                              initials,
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            )
                          : null,
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            avatar: const Icon(
                              Icons.manage_accounts,
                              size: 16,
                            ),
                            label: Text(
                              _roleLabel(role),
                            ),
                            visualDensity:
                                VisualDensity.compact,
                          ),

                          Chip(
                            label: Text(
                              _validationLabel(
                                validationStatus,
                              ),
                            ),
                            visualDensity:
                                VisualDensity.compact,
                            side: BorderSide(
                              color:
                                  _validationColor(
                                context,
                                validationStatus,
                              ),
                            ),
                          ),

                          if (isActive)
                            const Chip(
                              label: Text('Actif'),
                              visualDensity:
                                  VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Divider(),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                // Modifier
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () {
                    _edit(user);
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                  ),
                ),

                // Validation
                if (validationStatus == 'pending') ...[
                  IconButton(
                    tooltip: 'Valider',
                    onPressed: () {
                      _approve(user);
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                    ),
                  ),

                  IconButton(
                    tooltip: 'Refuser',
                    onPressed: () {
                      _reject(user);
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                    ),
                  ),
                ],

                // Supprimer
                if (!isCurrentUser)
                  IconButton(
                    tooltip: 'Supprimer',
                    onPressed: () {
                      _delete(user);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(Map<String, dynamic> user) {
    final first =
        user['first_name']?.toString().trim() ?? '';

    final last =
        user['last_name']?.toString().trim() ?? '';

    String result = '';

    if (first.isNotEmpty) {
      result += first[0];
    }

    if (last.isNotEmpty) {
      result += last[0];
    }

    if (result.isEmpty) {
      final email =
          user['email']?.toString().trim() ?? '';

      if (email.isNotEmpty) {
        return email[0].toUpperCase();
      }

      return 'U';
    }

    return result.toUpperCase();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    // Sécurité supplémentaire :
    // si non-admin dia tsy mampiseho warning na UI.
    if (!_isAdmin) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _users.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Icon(
                        Icons.people_outline,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Aucun utilisateur',
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(
                        context,
                        _users[index],
                      );
                    },
                  ),
      ),
    );
  }
}