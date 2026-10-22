import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  Map<String, dynamic>? _profile;

  List<int>? _localPhotoBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await Api.get(
        '/auth/profile/',
        cache: false,
      );

      if (!mounted) return;

      if (result is Map) {
        final data = Map<String, dynamic>.from(result);

        setState(() {
          _profile = data;
        });

        Api.user = data;
        await Api.saveUser();
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      if (Api.user != null) {
        setState(() {
          _profile = Map<String, dynamic>.from(Api.user!);
        });
      } else {
        _showError(e.message);
      }
    } catch (_) {
      if (!mounted) return;

      if (Api.user != null) {
        setState(() {
          _profile = Map<String, dynamic>.from(Api.user!);
        });
      } else {
        _showError(
          'Impossible de charger le profil.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // DATA
  // ============================================================

  String get _firstName {
    return _profile?['first_name']
            ?.toString()
            .trim() ??
        '';
  }

  String get _lastName {
    return _profile?['last_name']
            ?.toString()
            .trim() ??
        '';
  }

  String get _email {
    return _profile?['email']
            ?.toString()
            .trim() ??
        '';
  }

  String get _username {
    return _profile?['username']
            ?.toString()
            .trim() ??
        '';
  }

  String get _role {
    switch (_profile?['role']?.toString() ?? '') {
      case 'admin':
        return 'Administrateur';

      case 'technicien':
        return 'Technicien / Régisseur';

      case 'realisateur':
        return 'Chef opérateur / Réalisateur';

      default:
        return 'Utilisateur';
    }
  }

  String get _fullName {
    final name = '$_firstName $_lastName'.trim();

    if (name.isNotEmpty) {
      return name;
    }

    final complete =
        _profile?['nom_complet']
                ?.toString()
                .trim() ??
            '';

    if (complete.isNotEmpty) {
      return complete;
    }

    if (_username.isNotEmpty) {
      return _username;
    }

    return 'Utilisateur';
  }

  String get _initials {
    final parts = <String>[];

    if (_firstName.isNotEmpty) {
      parts.add(_firstName[0]);
    }

    if (_lastName.isNotEmpty) {
      parts.add(_lastName[0]);
    }

    if (parts.isEmpty && _username.isNotEmpty) {
      parts.add(_username[0]);
    }

    if (parts.isEmpty) {
      return 'U';
    }

    return parts.join().toUpperCase();
  }

  String get _photoValue {
    return _profile?['photo']
            ?.toString()
            .trim() ??
        '';
  }

  String get _photoUrl {
    final photo = _photoValue;

    if (photo.isEmpty) {
      return '';
    }

    return Api.fileUrl(photo);
  }

  // ============================================================
  // PHOTO
  // ============================================================

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        throw ApiException(
          'Le fichier image est vide.',
        );
      }

      if (!mounted) return;

      setState(() {
        _localPhotoBytes = bytes;
        _uploadingPhoto = true;
      });

      final result = await Api.patchMultipart(
        '/auth/profile/',
        payload: {},
        photoBytes: bytes,
        photoName: image.name.isNotEmpty
            ? image.name
            : 'profile.jpg',
      );

      if (!mounted) return;

      if (result is Map) {
        final data =
            Map<String, dynamic>.from(result);

        setState(() {
          _profile = data;
          _localPhotoBytes = null;
        });

        Api.user = data;
        await Api.saveUser();

        if (!mounted) return;

        _showSuccess(
          'Photo de profil enregistrée.',
        );
      } else {
        throw ApiException(
          'Réponse invalide du serveur.',
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _localPhotoBytes = null;
      });

      _showError(e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _localPhotoBytes = null;
      });

      _showError(
        'Impossible d’enregistrer la photo.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  Future<void> _editProfile() async {
    final values =
        await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _EditProfileDialog(
          firstName: _firstName,
          lastName: _lastName,
          email: _email,
        );
      },
    );

    if (values == null || !mounted) {
      return;
    }

    await _saveProfile(values);
  }

  Future<void> _saveProfile(
    Map<String, String> values,
  ) async {
    if (_saving) return;

    final firstName =
        values['first_name']?.trim() ?? '';

    final lastName =
        values['last_name']?.trim() ?? '';

    final email =
        values['email']?.trim() ?? '';

    if (firstName.isEmpty) {
      _showError(
        'Le prénom est obligatoire.',
      );
      return;
    }

    if (email.isEmpty) {
      _showError(
        'L’adresse email est obligatoire.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final result = await Api.patch(
        '/auth/profile/',
        {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        },
      );

      if (!mounted) return;

      if (result is Map) {
        final data =
            Map<String, dynamic>.from(result);

        setState(() {
          _profile = data;
        });

        Api.user = data;
        await Api.saveUser();

        if (!mounted) return;

        _showSuccess(
          'Profil enregistré avec succès.',
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      _showError(e.message);
    } catch (_) {
      if (!mounted) return;

      _showError(
        'Impossible d’enregistrer les modifications.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE ACCOUNT
  // ============================================================

  Future<void> _deleteAccount() async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(22),
          ),
          title: const Text(
            'Supprimer le compte',
          ),
          content: const Text(
            'Cette action est définitive. '
            'Voulez-vous vraiment supprimer votre compte ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Annuler',
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Supprimer',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await Api.delete(
        '/auth/profile/',
      );

      await Api.logout();

      if (!mounted) return;

      Navigator.of(context)
          .pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showError(
        'Impossible de supprimer le compte.',
      );
    }
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar() {
    if (_localPhotoBytes != null &&
        _localPhotoBytes!.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          Uint8List.fromList(
            _localPhotoBytes!,
          ),
          width: 116,
          height: 116,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return _defaultAvatar();
          },
        ),
      );
    }

    if (_photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _photoUrl,
          width: 116,
          height: 116,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return _defaultAvatar();
          },
        ),
      );
    }

    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    final scheme =
        Theme.of(context).colorScheme;

    return Container(
      width: 116,
      height: 116,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer,
          ],
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE ACTION CARD
  // ============================================================

  Widget _profileActionCard({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    required bool danger,
  }) {
    final scheme =
        Theme.of(context).colorScheme;

    final Color iconBackground = danger
        ? Colors.red.withValues(alpha: .10)
        : scheme.primaryContainer;

    final Color iconColor = danger
        ? Colors.red.shade700
        : scheme.onPrimaryContainer;

    final Color titleColor = danger
        ? Colors.red.shade700
        : scheme.onSurface;

    final Color borderColor = danger
        ? Colors.red.withValues(alpha: .20)
        : scheme.outlineVariant.withValues(
            alpha: .45,
          );

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 72,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: .035,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBackground,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 27,
                color: danger
                    ? Colors.red.shade400
                    : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUCCESS / ERROR
  // ============================================================

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              Colors.red.shade700,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final scheme =
        Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          scheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ==================================================
            // PROFILE HEADER
            // ==================================================

            SliverAppBar(
              pinned: true,
              expandedHeight: 310,
              elevation: 0,
              backgroundColor:
                  scheme.primary,
              iconTheme:
                  const IconThemeData(
                color: Colors.white,
              ),
              flexibleSpace:
                  FlexibleSpaceBar(
                background: Container(
                  decoration:
                      BoxDecoration(
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        scheme.primary
                            .withValues(
                          alpha: .82,
                        ),
                        scheme.secondary,
                      ],
                    ),
                    borderRadius:
                        const BorderRadius.only(
                      bottomLeft:
                          Radius.circular(30),
                      bottomRight:
                          Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 30,
                        ),

                        // AVATAR
                        Stack(
                          clipBehavior:
                              Clip.none,
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              padding:
                                  const EdgeInsets
                                      .all(6),
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color:
                                    Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors
                                        .black
                                        .withValues(
                                      alpha: .20,
                                    ),
                                    blurRadius: 25,
                                    offset:
                                        const Offset(
                                      0,
                                      10,
                                    ),
                                  ),
                                ],
                              ),
                              child: _avatar(),
                            ),

                            // CAMERA
                            Positioned(
                              right: -3,
                              bottom: 2,
                              child: Material(
                                color:
                                    Colors.white,
                                shape:
                                    const CircleBorder(),
                                elevation: 6,
                                child:
                                    InkWell(
                                  customBorder:
                                      const CircleBorder(),
                                  onTap:
                                      _uploadingPhoto
                                          ? null
                                          : _pickPhoto,
                                  child:
                                      Container(
                                    width: 46,
                                    height: 46,
                                    alignment:
                                        Alignment
                                            .center,
                                    decoration:
                                        BoxDecoration(
                                      shape:
                                          BoxShape
                                              .circle,
                                      color: scheme
                                          .primaryContainer,
                                    ),
                                    child:
                                        _uploadingPhoto
                                            ? const SizedBox(
                                                width:
                                                    21,
                                                height:
                                                    21,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth:
                                                      2.5,
                                                ),
                                              )
                                            : Icon(
                                                Icons
                                                    .camera_alt_rounded,
                                                color: scheme
                                                    .onPrimaryContainer,
                                              ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        // NOM
                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 20,
                          ),
                          child: Text(
                            _fullName,
                            textAlign:
                                TextAlign.center,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        // EMAIL
                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 24,
                          ),
                          child: Text(
                            _email.isNotEmpty
                                ? _email
                                : 'Email non renseigné',
                            textAlign:
                                TextAlign.center,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha: .88,
                              ),
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 9,
                        ),

                        // ROLE
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .white
                                .withValues(
                              alpha: .16,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              30,
                            ),
                            border:
                                Border.all(
                              color: Colors
                                  .white
                                  .withValues(
                                alpha: .10,
                              ),
                            ),
                          ),
                          child: Text(
                            _role,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            SliverPadding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                28,
                16,
                40,
              ),
              sliver: SliverList(
                delegate:
                    SliverChildListDelegate(
                  [
                    // ==================================================
                    // MODIFIER
                    // ==================================================

                    _profileActionCard(
                      icon:
                          Icons.edit_rounded,
                      title:
                          'Modifier le profil',
                      onTap: _saving
                          ? null
                          : _editProfile,
                      danger: false,
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    // ==================================================
                    // SUPPRIMER
                    // ==================================================

                    _profileActionCard(
                      icon: Icons
                          .delete_outline_rounded,
                      title:
                          'Supprimer le compte',
                      onTap: _saving
                          ? null
                          : _deleteAccount,
                      danger: true,
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    // ==================================================
                    // PHOTO INFO
                    // ==================================================

                    // Container(
                    //   padding:
                    //       const EdgeInsets.all(
                    //     16,
                    //   ),
                    //   decoration:
                    //       BoxDecoration(
                    //     color: scheme
                    //         .primaryContainer
                    //         .withValues(
                    //       alpha: .30,
                    //     ),
                    //     borderRadius:
                    //         BorderRadius.circular(
                    //       18,
                    //     ),
                    //   ),
                    //   child: Row(
                    //     children: [
                    //       Container(
                    //         width: 44,
                    //         height: 44,
                    //         alignment:
                    //             Alignment.center,
                    //         decoration:
                    //             BoxDecoration(
                    //           shape:
                    //               BoxShape.circle,
                    //           color: scheme
                    //               .primaryContainer,
                    //         ),
                    //         child: Icon(
                    //           Icons
                    //               .photo_camera_rounded,
                    //           color: scheme
                    //               .onPrimaryContainer,
                    //         ),
                    //       ),
                    //       const SizedBox(
                    //         width: 12,
                    //       ),
                    //       Expanded(
                    //         child: Text(
                    //           'Appuyez sur l’icône caméra pour modifier votre photo de profil.',
                    //           style: Theme.of(
                    //             context,
                    //           )
                    //               .textTheme
                    //               .bodySmall
                    //               ?.copyWith(
                    //                 height: 1.4,
                    //               ),
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// DIALOGUE MODIFICATION
// ==================================================================

class _EditProfileDialog
    extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;

  const _EditProfileDialog({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  @override
  State<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState
    extends State<_EditProfileDialog> {
  late final TextEditingController
      _firstNameController;

  late final TextEditingController
      _lastNameController;

  late final TextEditingController
      _emailController;

  final GlobalKey<FormState>
      _formKey =
          GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _firstNameController =
        TextEditingController(
      text: widget.firstName,
    );

    _lastNameController =
        TextEditingController(
      text: widget.lastName,
    );

    _emailController =
        TextEditingController(
      text: widget.email,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    Navigator.of(context).pop(
      {
        'first_name':
            _firstNameController.text
                .trim(),
        'last_name':
            _lastNameController.text
                .trim(),
        'email':
            _emailController.text
                .trim(),
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final scheme =
        Theme.of(context)
            .colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(22),
      ),
      title: Row(
        children: [
          Icon(
            Icons.edit_rounded,
            color: scheme.primary,
          ),
          const SizedBox(
            width: 10,
          ),
          const Text(
            'Modifier le profil',
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextFormField(
                controller:
                    _firstNameController,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon:
                      Icon(
                    Icons
                        .person_outline,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
                validator:
                    (value) {
                  if (value ==
                          null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Le prénom est obligatoire';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                    _lastNameController,
                textInputAction:
                    TextInputAction.next,
                decoration:
                    const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon:
                      Icon(
                    Icons
                        .badge_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                    _emailController,
                keyboardType:
                    TextInputType
                        .emailAddress,
                textInputAction:
                    TextInputAction.done,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Adresse email',
                  prefixIcon:
                      Icon(
                    Icons
                        .email_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
                validator:
                    (value) {
                  final email =
                      value?.trim() ??
                          '';

                  if (email.isEmpty) {
                    return 'L’email est obligatoire';
                  }

                  final regex =
                      RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  );

                  if (!regex
                      .hasMatch(
                          email)) {
                    return 'Adresse email invalide';
                  }

                  return null;
                },
                onFieldSubmitted:
                    (_) {
                  _submit();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child: const Text(
            'Annuler',
          ),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(
            Icons.save_rounded,
          ),
          label: const Text(
            'Enregistrer',
          ),
        ),
      ],
    );
  }
}