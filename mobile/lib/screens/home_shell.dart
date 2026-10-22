import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';

import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'login_screen.dart';
import 'projects_screen.dart';
import 'scan_screen.dart';
import 'emprunts_screen.dart';
import 'profile_screen.dart';
import 'users_screen.dart';
import 'notification_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  int _unreadNotifications = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    Api.sync();

    _loadUnreadNotifications();

    // Vérification périodique des nouvelles notifications.
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _loadUnreadNotifications();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    super.dispose();
  }

  // ================================================================
  // APP LIFECYCLE
  // ================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadNotifications();
    }
  }

  // ================================================================
  // NOTIFICATIONS
  // ================================================================

  Future<void> _loadUnreadNotifications() async {
    try {
      final result = await Api.get(
        '/notifications/',
        cache: false,
      );

      if (!mounted) return;

      if (result is List) {
        int count = 0;

        for (final item in result) {
          if (item is Map) {
            final notification =
                Map<String, dynamic>.from(item);

            if (notification['lu'] != true) {
              count++;
            }
          }
        }

        if (mounted) {
          setState(() {
            _unreadNotifications = count;
          });
        }
      }
    } catch (_) {
      // On ne bloque pas l'application si le serveur
      // n'est momentanément pas disponible.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );

    // Après retour de NotificationScreen,
    // on actualise le nombre des notifications non lues.
    await _loadUnreadNotifications();
  }

  // ================================================================
  // LOGOUT
  // ================================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Déconnexion',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Voulez-vous vraiment vous déconnecter ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await Api.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  // ================================================================
  // PAGES PRINCIPALES
  // ================================================================

  List<Widget> get _pages => const [
        DashboardScreen(),
        InventoryScreen(),
        ProjectsScreen(),
        EmpruntsScreen(),
        ProfileScreen(),
        UsersScreen(),
      ];

  // ================================================================
  // TITRE
  // ================================================================

  String get _title {
    switch (_selectedIndex) {
      case 0:
        return 'Accueil';
      case 1:
        return 'Inventaire';
      case 2:
        return 'Projets';
      case 3:
        return 'Emprunts';
      case 4:
        return 'Profil';
      case 5:
        return 'Utilisateurs';
      default:
        return 'Gestion Matériel';
    }
  }

  // ================================================================
  // NAVIGATION
  // ================================================================

  void _selectPage(int index) {
    Navigator.pop(context);

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // ================================================================
  // SCANNER QR
  // ================================================================

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScanScreen(),
      ),
    );
  }

  // ================================================================
  // NOTIFICATION BADGE
  // ================================================================

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(
            Icons.notifications_rounded,
          ),
          onPressed: _openNotifications,
        ),

        if (_unreadNotifications > 0)
          Positioned(
            right: 3,
            top: 3,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .appBarTheme
                      .backgroundColor ??
                      Theme.of(context)
                          .colorScheme
                          .surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                _unreadNotifications > 99
                    ? '99+'
                    : _unreadNotifications.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,

        // ----------------------------------------------------------
        // MENU
        // ----------------------------------------------------------

        leading: Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Menu',
              icon: const Icon(
                Icons.menu_rounded,
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),

        // ----------------------------------------------------------
        // NOTIFICATIONS + QR SCANNER
        // ----------------------------------------------------------

        actions: [
          _notificationButton(),

          IconButton(
            tooltip: 'Scanner QR',
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
            ),
            onPressed: _openScanner,
          ),

          const SizedBox(width: 6),
        ],
      ),

      // ============================================================
      // BODY
      // ============================================================

      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
    );
  }

  // ================================================================
  // DRAWER
  // ================================================================

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final u = Api.user ?? <String, dynamic>{};

    final String fullName =
        (u['nom_complet'] ??
                '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}')
            .toString()
            .trim();

    final String name = fullName.isEmpty
        ? (u['username'] ?? 'Utilisateur').toString()
        : fullName;

    final String email =
        (u['email'] ?? '').toString().trim();

    final String role =
        (u['role'] ?? '').toString().trim().toLowerCase();

    final bool isAdmin = role == 'admin';

    final String photoValue =
        (u['photo'] ?? '').toString().trim();

    final String photoUrl =
        Api.fileUrl(photoValue);

    final String initials =
        _getInitials(name);

    return Drawer(
      width: 320,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(
              context,
              name: name,
              email: email,
              role: role,
              initials: initials,
              photoUrl: photoUrl,
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                children: [
                  // ==================================================
                  // ACCUEIL
                  // ==================================================

                  _drawerItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    title: 'Accueil',
                    selected: _selectedIndex == 0,
                    onTap: () => _selectPage(0),
                  ),

                  // ==================================================
                  // INVENTAIRE
                  // ==================================================

                  _drawerItem(
                    context,
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2_rounded,
                    title: 'Inventaire',
                    subtitle: 'Gestion du matériel',
                    selected: _selectedIndex == 1,
                    onTap: () => _selectPage(1),
                  ),

                  // ==================================================
                  // PROJETS
                  // ==================================================

                  _drawerItem(
                    context,
                    icon: Icons.movie_creation_outlined,
                    activeIcon: Icons.movie_creation_rounded,
                    title: 'Projets',
                    subtitle: 'Tournages et réservations',
                    selected: _selectedIndex == 2,
                    onTap: () => _selectPage(2),
                  ),

                  // ==================================================
                  // EMPRUNTS
                  // ==================================================

                  _drawerItem(
                    context,
                    icon: Icons.assignment_return_outlined,
                    activeIcon:
                        Icons.assignment_return_rounded,
                    title: 'Emprunts',
                    subtitle: 'Matériels empruntés',
                    selected: _selectedIndex == 3,
                    onTap: () => _selectPage(3),
                  ),

                  // ==================================================
                  // PROFIL
                  // ==================================================

                  _drawerItem(
                    context,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    title: 'Profil',
                    subtitle: 'Compte utilisateur',
                    selected: _selectedIndex == 4,
                    onTap: () => _selectPage(4),
                  ),

                  // ==================================================
                  // UTILISATEURS - ADMIN UNIQUEMENT
                  // ==================================================

                  if (isAdmin) ...[
                    const SizedBox(height: 8),

                    const Divider(
                      indent: 12,
                      endIndent: 12,
                    ),

                    const SizedBox(height: 8),

                    _drawerItem(
                      context,
                      icon: Icons.manage_accounts_outlined,
                      activeIcon:
                          Icons.manage_accounts_rounded,
                      title: 'Utilisateurs',
                      subtitle: 'Gestion des comptes',
                      selected: _selectedIndex == 5,
                      onTap: () => _selectPage(5),
                    ),
                  ],

                  const SizedBox(height: 8),

                  if (!isAdmin)
                    const Divider(
                      indent: 12,
                      endIndent: 12,
                    ),

                  const SizedBox(height: 8),

                  // ==================================================
                  // DARK / LIGHT
                  // ==================================================

                  ValueListenableBuilder<bool>(
                    valueListenable: AppTheme.isDark,
                    builder: (
                      context,
                      isDark,
                      _,
                    ) {
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme
                                .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                          ),
                        ),
                        title: Text(
                          isDark
                              ? 'Mode sombre'
                              : 'Mode clair',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Apparence actuelle',
                        ),
                        trailing: Switch.adaptive(
                          value: isDark,
                          onChanged: (_) {
                            AppTheme.toggle();
                          },
                        ),
                        onTap: () {
                          AppTheme.toggle();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // ========================================================
            // FOOTER
            // ========================================================

            _buildDrawerFooter(context),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // DRAWER HEADER
  // ================================================================

  Widget _buildDrawerHeader(
    BuildContext context, {
    required String name,
    required String email,
    required String role,
    required String initials,
    required String photoUrl,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        26,
        18,
        22,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return _drawerInitialAvatar(
                            context,
                            initials,
                          );
                        },
                      )
                    : _drawerInitialAvatar(
                        context,
                        initials,
                      ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: theme
                          .textTheme.titleMedium
                          ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    if (role.isNotEmpty) ...[
                      const SizedBox(height: 7),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary
                              .withValues(
                            alpha: 0.15,
                          ),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          _roleLabel(role)
                              .toUpperCase(),
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight:
                                FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (email.isNotEmpty) ...[
            const SizedBox(height: 17),

            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 17,
                  color: scheme
                      .onPrimaryContainer
                      .withValues(
                    alpha: 0.70,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: theme
                        .textTheme.bodySmall
                        ?.copyWith(
                      color: scheme
                          .onPrimaryContainer
                          .withValues(
                        alpha: 0.70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // DRAWER AVATAR
  // ================================================================

  Widget _drawerInitialAvatar(
    BuildContext context,
    String initials,
  ) {
    final scheme =
        Theme.of(context).colorScheme;

    return Container(
      alignment: Alignment.center,
      color: scheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 25,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ================================================================
  // ROLE
  // ================================================================

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';

      case 'equipe':
        return 'Équipe';

      case 'utilisateur':
        return 'Utilisateur simple';

      // Compatibilité avec anciennes données
      case 'technicien':
        return 'Équipe';

      case 'realisateur':
        return 'Utilisateur simple';

      default:
        return role;
    }
  }

  // ================================================================
  // DRAWER ITEM
  // ================================================================

  Widget _drawerItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String title,
    String? subtitle,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final scheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        selected: selected,
        selectedTileColor:
            scheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(
                    alpha: 0.12,
                  )
                : scheme.surfaceContainerHighest,
            borderRadius:
                BorderRadius.circular(13),
          ),
          child: Icon(
            selected
                ? activeIcon
                : icon,
            color: selected
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
              )
            : null,
        trailing: selected
            ? Icon(
                Icons.chevron_right_rounded,
                color: scheme.primary,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  // ================================================================
  // FOOTER
  // ================================================================

  Widget _buildDrawerFooter(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        18,
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
              ),
              label: const Text(
                'Déconnexion',
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Gestion Matériel',
            style: theme
                .textTheme.bodySmall
                ?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(
                alpha: 0.55,
              ),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            'Version 1.0.0',
            style: theme
                .textTheme.labelSmall
                ?.copyWith(
              color: scheme.onSurface.withValues(
                alpha: 0.40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // INITIALS
  // ================================================================

  String _getInitials(String name) {
    final value = name.trim();

    if (value.isEmpty) {
      return 'U';
    }

    final parts = value
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return (
        parts.first[0] +
        parts.last[0]
      ).toUpperCase();
    }

    return parts.first[0].toUpperCase();
  }
}