import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  String _role = 'utilisateur';

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _loading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final result = await Api.post(
        '/auth/register/',
        {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _role,
          'password': _passwordController.text,
          'password_confirmation': _confirmationController.text,
        },
      );

      if (!mounted) return;

      // Raha inscription réussie
      if (result is Map &&
          (result['id'] != null ||
              result['user'] != null ||
              result['message'] != null)) {
        await _showSuccessDialog();
        return;
      }

      toast(
        context,
        'Compte créé avec succès. Il doit être validé par un administrateur.',
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      String message = 'Une erreur est survenue lors de l’inscription.';

      final error = e.toString();

      if (error.contains('email')) {
        message = 'Cette adresse email est déjà utilisée.';
      } else if (error.contains('username')) {
        message =
            'Impossible de créer automatiquement l’identifiant à partir de cet email.';
      } else if (error.contains('400')) {
        message = 'Vérifiez les informations saisies.';
      } else if (error.contains('403')) {
        message = 'Inscription refusée.';
      } else if (error.contains('500')) {
        message = 'Erreur du serveur. Réessayez plus tard.';
      }

      toast(context, message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Inscription réussie'),
              ),
            ],
          ),
          content: const Text(
            'Votre compte a été créé avec succès.\n\n'
            'Il est actuellement en attente de validation par un administrateur. '
            'Vous pourrez vous connecter une fois votre compte approuvé.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Compris'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.pop(context);
  }

  String? _validateFirstName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Le prénom est obligatoire';
    }

    if (text.length < 2) {
      return 'Le prénom est trop court';
    }

    return null;
  }

  String? _validateLastName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Le nom est obligatoire';
    }

    if (text.length < 2) {
      return 'Le nom est trop court';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'L’email est obligatoire';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Adresse email invalide';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Le mot de passe est obligatoire';
    }

    if (password.length < 8) {
      return 'Minimum 8 caractères';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    final confirmation = value ?? '';

    if (confirmation.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }

    if (confirmation != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / icône
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1,
                        size: 40,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Créer votre compte',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Remplissez les informations ci-dessous pour créer votre compte.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Prénom
                    TextFormField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [
                        AutofillHints.givenName,
                      ],
                      decoration: _inputDecoration(
                        label: 'Prénom',
                        icon: Icons.person_outline,
                      ),
                      validator: _validateFirstName,
                    ),

                    const SizedBox(height: 16),

                    // Nom
                    TextFormField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [
                        AutofillHints.familyName,
                      ],
                      decoration: _inputDecoration(
                        label: 'Nom',
                        icon: Icons.badge_outlined,
                      ),
                      validator: _validateLastName,
                    ),

                    const SizedBox(height: 16),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration: _inputDecoration(
                        label: 'Email',
                        icon: Icons.email_outlined,
                      ),
                      validator: _validateEmail,
                    ),

                    const SizedBox(height: 16),

                    // Type de compte
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: _inputDecoration(
                        label: 'Type de compte',
                        icon: Icons.manage_accounts_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'equipe',
                          child: Text('Équipe'),
                        ),
                        DropdownMenuItem(
                          value: 'utilisateur',
                          child: Text('Utilisateur simple'),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                _role = value;
                              });
                            },
                    ),

                    const SizedBox(height: 16),

                    // Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      decoration: _inputDecoration(
                        label: 'Mot de passe',
                        icon: Icons.lock_outline,
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),

                    const SizedBox(height: 16),

                    // Confirmation
                    TextFormField(
                      controller: _confirmationController,
                      obscureText: _obscureConfirmation,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) {
                        if (!_loading) {
                          _register();
                        }
                      },
                      decoration: _inputDecoration(
                        label: 'Confirmation du mot de passe',
                        icon: Icons.lock_reset_outlined,
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmation
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          onPressed: () {
                            setState(() {
                              _obscureConfirmation =
                                  !_obscureConfirmation;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validateConfirmation,
                    ),

                    const SizedBox(height: 12),

                    // // Information validation Admin
                    // Container(
                    //   padding: const EdgeInsets.all(14),
                    //   decoration: BoxDecoration(
                    //     color: colorScheme.secondaryContainer,
                    //     borderRadius: BorderRadius.circular(14),
                    //   ),
                    //   child: Row(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Icon(
                    //         Icons.info_outline,
                    //         color: colorScheme.onSecondaryContainer,
                    //       ),
                    //       const SizedBox(width: 12),
                    //       Expanded(
                    //         child: Text(
                    //           'Après votre inscription, votre compte devra être '
                    //           'validé par un administrateur avant de pouvoir '
                    //           'vous connecter.',
                    //           style: theme.textTheme.bodySmall?.copyWith(
                    //             color: colorScheme.onSecondaryContainer,
                    //           ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),

                    const SizedBox(height: 24),

                    // Bouton inscription
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Créer mon compte',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Retour connexion
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: const Text(
                        'J’ai déjà un compte',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}