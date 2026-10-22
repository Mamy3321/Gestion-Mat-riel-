import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';

enum NotificationType {
  accountValidated,
  lateLoan,
  maintenance,
  admin,
  normal,
}

enum NotificationRecipient {
  all,
  administrators,
  team,
  simpleUser,
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];

  bool _loading = true;
  bool _markingAll = false;

  // Suppression différée afin de permettre ANNULER.
  final Map<String, Timer> _deleteTimers = {};
  final Map<String, Map<String, dynamic>> _pendingDeleted = {};
  final Map<String, int> _pendingIndexes = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    for (final timer in _deleteTimers.values) {
      timer.cancel();
    }

    _deleteTimers.clear();
    _pendingDeleted.clear();
    _pendingIndexes.clear();

    super.dispose();
  }

  // ============================================================
  // CHARGEMENT DES NOTIFICATIONS
  // ============================================================

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final response = await Api.get('/notifications/');

      dynamic data = response;

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        data = data['results'];
      }

      if (data is List) {
        final notifications = data
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _notifications = [];
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showSnackBar(
        'Impossible de charger les notifications.',
        isError: true,
      );
    }
  }

  // ============================================================
  // MARQUER UNE NOTIFICATION COMME LUE
  // ============================================================

  Future<void> _markAsRead(
    Map<String, dynamic> notification,
  ) async {
    final id = notification['id'];

    if (id == null) return;

    final index = _notifications.indexWhere(
      (item) => item['id'].toString() == id.toString(),
    );

    if (index == -1) return;

    if (_notifications[index]['lu'] == true) {
      return;
    }

    try {
      await Api.post(
        '/notifications/$id/lire/',
      );

      if (!mounted) return;

      setState(() {
        _notifications[index]['lu'] = true;
      });
    } catch (_) {
      // On ne bloque pas l'interface.
    }
  }

  // ============================================================
  // MARQUER TOUTES LES NOTIFICATIONS COMME LUES
  // ============================================================

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;

    setState(() {
      _markingAll = true;
    });

    try {
      await Api.post(
        '/notifications/tout-lire/',
      );

      if (!mounted) return;

      setState(() {
        for (final notification in _notifications) {
          notification['lu'] = true;
        }

        _markingAll = false;
      });

      _showSnackBar(
        'Toutes les notifications sont lues.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _markingAll = false;
      });

      _showSnackBar(
        'Impossible de marquer toutes les notifications comme lues.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SUPPRESSION AVEC ANNULER
  // ============================================================

  void _dismissNotification(
    Map<String, dynamic> notification,
    int index,
  ) {
    final id = notification['id'];

    if (id == null) return;

    final idKey = id.toString();

    _deleteTimers[idKey]?.cancel();

    _pendingDeleted[idKey] =
        Map<String, dynamic>.from(notification);

    _pendingIndexes[idKey] = index;

    if (mounted) {
      setState(() {
        _notifications.removeWhere(
          (item) => item['id'].toString() == idKey,
        );
      });
    }

    _deleteTimers[idKey] = Timer(
      const Duration(seconds: 5),
      () => _deleteNotificationPermanently(idKey),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Notification supprimée',
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'ANNULER',
            onPressed: () {
              _undoDelete(idKey);
            },
          ),
        ),
      );
  }

  // ============================================================
  // ANNULER LA SUPPRESSION
  // ============================================================

  void _undoDelete(String idKey) {
    final timer = _deleteTimers[idKey];

    if (timer == null) return;

    timer.cancel();
    _deleteTimers.remove(idKey);

    final deletedNotification =
        _pendingDeleted.remove(idKey);

    final originalIndex =
        _pendingIndexes.remove(idKey);

    if (deletedNotification == null) return;

    if (!mounted) return;

    setState(() {
      final alreadyExists = _notifications.any(
        (item) => item['id'].toString() == idKey,
      );

      if (alreadyExists) return;

      if (originalIndex != null &&
          originalIndex >= 0 &&
          originalIndex <= _notifications.length) {
        _notifications.insert(
          originalIndex,
          deletedNotification,
        );
      } else {
        _notifications.add(
          deletedNotification,
        );
      }
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Suppression annulée',
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // DELETE DÉFINITIF
  // ============================================================

  Future<void> _deleteNotificationPermanently(
    String idKey,
  ) async {
    _deleteTimers.remove(idKey);

    final deletedNotification =
        _pendingDeleted.remove(idKey);

    final originalIndex =
        _pendingIndexes.remove(idKey);

    if (deletedNotification == null) {
      return;
    }

    final id = deletedNotification['id'];

    try {
      await Api.delete(
        '/notifications/$id/',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        final alreadyExists = _notifications.any(
          (item) => item['id'].toString() == idKey,
        );

        if (alreadyExists) return;

        if (originalIndex != null &&
            originalIndex >= 0 &&
            originalIndex <= _notifications.length) {
          _notifications.insert(
            originalIndex,
            deletedNotification,
          );
        } else {
          _notifications.add(
            deletedNotification,
          );
        }
      });

      _showSnackBar(
        'Impossible de supprimer la notification.',
        isError: true,
      );
    }
  }

  // ============================================================
  // OUVRIR FORMULAIRE ADMIN
  // ============================================================

  Future<void> _openAddNotificationDialog() async {
    if (!Api.isAdmin) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const _AddNotificationDialog(),
    );

    if (created == true && mounted) {
      await _loadNotifications();

      _showSnackBar(
        'Notification envoyée avec succès.',
      );
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? Colors.red.shade700 : null,
        ),
      );
  }

  // ============================================================
  // TYPE NOTIFICATION
  // ============================================================

  NotificationType _getNotificationType(
    Map<String, dynamic> notification,
  ) {
    final titre = (
      notification['titre'] ?? ''
    ).toString().toLowerCase();

    final message = (
      notification['message'] ?? ''
    ).toString().toLowerCase();

    final text = '$titre $message';

    if (text.contains('compte valid') ||
        text.contains('compte approuv') ||
        text.contains('identifiant')) {
      return NotificationType.accountValidated;
    }

    if (text.contains('emprunt') &&
        text.contains('retard')) {
      return NotificationType.lateLoan;
    }

    if (text.contains('maintenance')) {
      return NotificationType.maintenance;
    }

    if (text.contains('administrateur') ||
        text.contains('admin')) {
      return NotificationType.admin;
    }

    return NotificationType.normal;
  }

  // ============================================================
  // ICÔNE
  // ============================================================

  IconData _getIcon(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.accountValidated:
        return Icons.verified_user_rounded;

      case NotificationType.lateLoan:
        return Icons.assignment_late_rounded;

      case NotificationType.maintenance:
        return Icons.build_circle_rounded;

      case NotificationType.admin:
        return Icons.admin_panel_settings_rounded;

      case NotificationType.normal:
        return Icons.notifications_rounded;
    }
  }

  // ============================================================
  // LABEL
  // ============================================================

  String _getLabel(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.accountValidated:
        return 'Compte';

      case NotificationType.lateLoan:
        return 'Emprunt';

      case NotificationType.maintenance:
        return 'Maintenance';

      case NotificationType.admin:
        return 'Administrateur';

      case NotificationType.normal:
        return 'Notification';
    }
  }

  // ============================================================
  // COULEUR
  // ============================================================

  Color _getTypeColor(
    NotificationType type,
  ) {
    switch (type) {
      case NotificationType.accountValidated:
        return Colors.green;

      case NotificationType.lateLoan:
        return Colors.orange;

      case NotificationType.maintenance:
        return Colors.amber;

      case NotificationType.admin:
        return Colors.deepPurple;

      case NotificationType.normal:
        return Colors.blue;
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date =
          DateTime.parse(
            value.toString(),
          ).toLocal();

      final day =
          date.day.toString().padLeft(2, '0');

      final month =
          date.month.toString().padLeft(2, '0');

      final year =
          date.year.toString();

      final hour =
          date.hour.toString().padLeft(2, '0');

      final minute =
          date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year à $hour:$minute';
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (Api.isAdmin)
            IconButton(
              tooltip: 'Nouvelle notification',
              onPressed:
                  _openAddNotificationDialog,
              icon: const Icon(
                Icons.add_alert_rounded,
              ),
            ),

          if (_notifications.any(
            (notification) =>
                notification['lu'] != true,
          ))
            IconButton(
              tooltip:
                  'Tout marquer comme lu',
              onPressed: _markingAll
                  ? null
                  : _markAllAsRead,
              icon: _markingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.done_all_rounded,
                    ),
            ),

          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading
                ? null
                : _loadNotifications,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // IMPORTANT :
      // Il n'y a aucune catégorie de destinataire ici.
      // Les catégories sont uniquement dans le formulaire
      // d'ajout d'une notification.
      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          24,
        ),
        itemCount: _notifications.length,
        itemBuilder: (
          context,
          index,
        ) {
          final notification =
              _notifications[index];

          return _buildNotificationItem(
            notification,
            index,
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(
                    alpha: 0.35,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune notification',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(
                      alpha: 0.65,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous serez informé ici des événements importants.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(
                      alpha: 0.50,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION ITEM
  // ============================================================

  Widget _buildNotificationItem(
    Map<String, dynamic> notification,
    int index,
  ) {
    final type =
        _getNotificationType(
      notification,
    );

    final color =
        _getTypeColor(type);

    final title = (
      notification['titre'] ??
      'Notification'
    ).toString();

    final message = (
      notification['message'] ??
      ''
    ).toString();

    final created =
        notification['created'];

    final isRead =
        notification['lu'] == true;

    final id =
        notification['id'];

    return Dismissible(
      key: ValueKey(
        'notification-${id ?? index}',
      ),

      direction:
          DismissDirection.horizontal,

      background:
          _buildDismissBackground(
        Alignment.centerLeft,
      ),

      secondaryBackground:
          _buildDismissBackground(
        Alignment.centerRight,
      ),

      confirmDismiss: (_) async {
        _dismissNotification(
          notification,
          index,
        );

        return true;
      },

      child: Padding(
        padding:
            const EdgeInsets.only(
          bottom: 10,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                BorderRadius.circular(16),
            onTap: () =>
                _markAsRead(
              notification,
            ),
            child: Container(
              padding:
                  const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(16),
                color: isRead
                    ? Theme.of(context)
                        .colorScheme
                        .surface
                    : Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(
                          alpha: 0.08,
                        ),
                border: Border.all(
                  color: isRead
                      ? Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(
                            alpha: 0.15,
                          )
                      : color.withValues(
                          alpha: 0.35,
                        ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          color.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    child: Icon(
                      _getIcon(type),
                      color: color,
                      size: 23,
                    ),
                  ),

                  const SizedBox(
                    width: 13,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      isRead
                                          ? FontWeight
                                              .w500
                                          : FontWeight
                                              .w700,
                                ),
                              ),
                            ),

                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin:
                                    const EdgeInsets
                                        .only(
                                  left: 8,
                                  top: 6,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: color,
                                  shape:
                                      BoxShape
                                          .circle,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        if (message.isNotEmpty)
                          Text(
                            message,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.35,
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),

                        const SizedBox(
                          height: 9,
                        ),

                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  7,
                                ),
                                color:
                                    color.withValues(
                                  alpha: 0.10,
                                ),
                              ),
                              child: Text(
                                _getLabel(type),
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color: color,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            if (created != null)
                              Expanded(
                                child: Text(
                                  _formatDate(
                                    created,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    )
                                        .colorScheme
                                        .onSurface
                                        .withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SWIPE BACKGROUND
  // ============================================================

  Widget _buildDismissBackground(
    Alignment alignment,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(16),
        color: Colors.red.withValues(
          alpha: 0.12,
        ),
      ),
      alignment: alignment,
      child: Icon(
        Icons.delete_outline_rounded,
        color: Colors.red.shade400,
        size: 28,
      ),
    );
  }
}

// ============================================================================
// DIALOGUE : AJOUTER UNE NOTIFICATION
// ============================================================================

class _AddNotificationDialog
    extends StatefulWidget {
  const _AddNotificationDialog();

  @override
  State<_AddNotificationDialog> createState() =>
      _AddNotificationDialogState();
}

class _AddNotificationDialogState
    extends State<_AddNotificationDialog> {
  final _formKey =
      GlobalKey<FormState>();

  final _titleController =
      TextEditingController();

  final _messageController =
      TextEditingController();

  // Par défaut : Tout le monde
  NotificationRecipient _recipient =
      NotificationRecipient.all;

  List<Map<String, dynamic>> _users =
      [];

  dynamic _selectedTarget;

  bool _loadingUsers = false;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();

    super.dispose();
  }

  // ============================================================
  // CHARGER LES UTILISATEURS
  // ============================================================

  Future<void> _loadUsers() async {
    if (_loadingUsers) return;

    setState(() {
      _loadingUsers = true;
    });

    try {
      final response =
          await Api.get('/users/');

      dynamic data = response;

      if (data is Map<String, dynamic> &&
          data['results'] is List) {
        data = data['results'];
      }

      if (data is List) {
        final users = data
            .whereType<Map>()
            .map(
              (user) =>
                  Map<String, dynamic>.from(
                user,
              ),
            )
            .where(
              (user) => user['id'] != null,
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _users = users;
          _loadingUsers = false;
        });
      } else {
        if (!mounted) return;

        setState(() {
          _users = [];
          _loadingUsers = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingUsers = false;
      });

      _showDialogSnackBar(
        'Impossible de charger les utilisateurs.',
        isError: true,
      );
    }
  }

  // ============================================================
  // CHANGEMENT DESTINATAIRE
  // ============================================================

  Future<void> _changeRecipient(
    NotificationRecipient? value,
  ) async {
    if (value == null) return;

    setState(() {
      _recipient = value;
      _selectedTarget = 'tous';
    });

    if (value != NotificationRecipient.all &&
        _users.isEmpty) {
      await _loadUsers();
    }
  }

  // ============================================================
  // ROLE UTILISATEUR
  // ============================================================

  String _getUserRole(
    Map<String, dynamic> user,
  ) {
    return (
      user['role'] ?? ''
    ).toString().trim().toLowerCase();
  }

  // ============================================================
  // NOM UTILISATEUR
  // ============================================================

  String _getUserName(
    Map<String, dynamic> user,
  ) {
    final fullName =
        user['nom_complet'] ??
        user['full_name'] ??
        user['name'];

    if (fullName != null &&
        fullName
            .toString()
            .trim()
            .isNotEmpty) {
      return fullName.toString();
    }

    final username =
        user['username'];

    if (username != null &&
        username
            .toString()
            .trim()
            .isNotEmpty) {
      return username.toString();
    }

    final email =
        user['email'];

    if (email != null &&
        email
            .toString()
            .trim()
            .isNotEmpty) {
      return email.toString();
    }

    return 'Utilisateur #${user['id']}';
  }

  // ============================================================
  // FILTRER LES UTILISATEURS
  // ============================================================

  List<Map<String, dynamic>>
      _filteredUsers() {
    switch (_recipient) {
      case NotificationRecipient.all:
        return [];

      case NotificationRecipient
            .administrators:
        return _users
            .where(
              (user) =>
                  _getUserRole(user) ==
                  'admin',
            )
            .toList();

      case NotificationRecipient.team:
        return _users
            .where(
              (user) =>
                  _getUserRole(user) ==
                  'equipe',
            )
            .toList();

      case NotificationRecipient
            .simpleUser:
        return _users
            .where(
              (user) =>
                  _getUserRole(user) ==
                  'utilisateur',
            )
            .toList();
    }
  }

  // ============================================================
  // LABEL DESTINATAIRE
  // ============================================================

  String _recipientLabel(
    NotificationRecipient recipient,
  ) {
    switch (recipient) {
      case NotificationRecipient.all:
        return 'Tout le monde';

      case NotificationRecipient
            .administrators:
        return 'Administrateur';

      case NotificationRecipient.team:
        return 'Équipe';

      case NotificationRecipient
            .simpleUser:
        return 'Utilisateur simple';
    }
  }

  // ============================================================
  // ICÔNE DESTINATAIRE
  // ============================================================

  IconData _recipientIcon(
    NotificationRecipient recipient,
  ) {
    switch (recipient) {
      case NotificationRecipient.all:
        return Icons.groups_rounded;

      case NotificationRecipient
            .administrators:
        return Icons
            .admin_panel_settings_rounded;

      case NotificationRecipient.team:
        return Icons.groups_2_rounded;

      case NotificationRecipient
            .simpleUser:
        return Icons.person_rounded;
    }
  }

  // ============================================================
  // DESCRIPTION DESTINATAIRE
  // ============================================================

  String _recipientDescription() {
    switch (_recipient) {
      case NotificationRecipient.all:
        return 'La notification sera envoyée à tout le monde.';

      case NotificationRecipient
            .administrators:
        return 'La notification sera envoyée aux administrateurs sélectionnés.';

      case NotificationRecipient.team:
        return 'La notification sera envoyée aux membres de l’équipe sélectionnés.';

      case NotificationRecipient
            .simpleUser:
        return 'La notification sera envoyée aux utilisateurs simples sélectionnés.';
    }
  }

  // ============================================================
  // LABEL "TOUS"
  // ============================================================

  String _allTargetLabel() {
    switch (_recipient) {
      case NotificationRecipient.all:
        return 'Tout le monde';

      case NotificationRecipient
            .administrators:
        return 'Tous les administrateurs';

      case NotificationRecipient.team:
        return 'Toutes les équipes';

      case NotificationRecipient
            .simpleUser:
        return 'Tous les utilisateurs simples';
    }
  }

  // ============================================================
  // ENVOYER
  // ============================================================

  Future<void> _send() async {
    if (_sending) return;

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_recipient !=
            NotificationRecipient.all &&
        _selectedTarget == null) {
      _showDialogSnackBar(
        'Veuillez sélectionner un destinataire.',
        isError: true,
      );

      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      String destinataire;

      switch (_recipient) {
        case NotificationRecipient.all:
          destinataire =
              'tout_le_monde';
          break;

        case NotificationRecipient
              .administrators:
          destinataire =
              'administrateur';
          break;

        case NotificationRecipient.team:
          destinataire = 'equipe';
          break;

        case NotificationRecipient
              .simpleUser:
          destinataire =
              'utilisateur';
          break;
      }

      final Map<String, dynamic> body =
          {
        'destinataire':
            destinataire,
        'cible':
            _selectedTarget ?? 'tous',
        'titre':
            _titleController.text.trim(),
        'message':
            _messageController.text.trim(),
      };

      await Api.post(
        '/notifications/envoyer/',
        body,
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      _showDialogSnackBar(
        'Impossible d’envoyer la notification.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SNACKBAR DIALOG
  // ============================================================

  void _showDialogSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration:
              const Duration(seconds: 3),
          behavior:
              SnackBarBehavior.floating,
          backgroundColor: isError
              ? Colors.red.shade700
              : null,
        ),
      );
  }

  // ============================================================
  // BUILD DIALOG
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final filteredUsers =
        _filteredUsers();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.add_alert_rounded,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(
            width: 10,
          ),
          const Expanded(
            child: Text(
              'Nouvelle notification',
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==================================================
                // DESTINATAIRE PRINCIPAL
                // ==================================================

                const Text(
                  'Destinataire',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                DropdownButtonFormField<
                    NotificationRecipient>(
                  initialValue:
                      _recipient,

                  decoration:
                      const InputDecoration(
                    border:
                        OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons
                          .person_add_alt_1_rounded,
                    ),
                  ),

                  items:
                      NotificationRecipient
                          .values
                          .map(
                            (
                              recipient,
                            ) {
                              return DropdownMenuItem<
                                  NotificationRecipient>(
                                value:
                                    recipient,
                                child: Row(
                                  children: [
                                    Icon(
                                      _recipientIcon(
                                        recipient,
                                      ),
                                      size: 20,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      _recipientLabel(
                                        recipient,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                          .toList(),

                  onChanged:
                      _sending
                          ? null
                          : _changeRecipient,
                ),

                const SizedBox(
                  height: 7,
                ),

                Text(
                  _recipientDescription(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    )
                        .colorScheme
                        .onSurface
                        .withValues(
                      alpha: 0.55,
                    ),
                  ),
                ),

                // ==================================================
                // LISTE DESTINATAIRE
                // ==================================================

                if (_recipient !=
                    NotificationRecipient
                        .all) ...[
                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'Sélection',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  if (_loadingUsers)
                    const Center(
                      child: Padding(
                        padding:
                            EdgeInsets.all(
                          12,
                        ),
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<
                        dynamic>(
                      initialValue:
                          _selectedTarget,

                      decoration:
                          const InputDecoration(
                        border:
                            OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons
                              .people_alt_rounded,
                        ),
                      ),

                      items: [
                        DropdownMenuItem<
                            dynamic>(
                          value: 'tous',
                          child: Text(
                            _allTargetLabel(),
                          ),
                        ),

                        ...filteredUsers
                            .map(
                          (
                            user,
                          ) {
                            return DropdownMenuItem<
                                dynamic>(
                              value:
                                  user['id'],
                              child: Text(
                                _getUserName(
                                  user,
                                ),
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            );
                          },
                        ),
                      ],

                      onChanged:
                          _sending
                              ? null
                              : (
                                  value,
                                ) {
                                  setState(() {
                                    _selectedTarget =
                                        value;
                                  });
                                },

                      validator: (
                        value,
                      ) {
                        if (_recipient !=
                                NotificationRecipient
                                    .all &&
                            value == null) {
                          return 'Sélectionnez un destinataire';
                        }

                        return null;
                      },
                    ),
                ],

                // ==================================================
                // TITRE
                // ==================================================

                const SizedBox(
                  height: 18,
                ),

                const Text(
                  'Titre',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                TextFormField(
                  controller:
                      _titleController,
                  enabled: !_sending,
                  textInputAction:
                      TextInputAction.next,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Titre de la notification',
                    border:
                        OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.title_rounded,
                    ),
                  ),

                  validator: (
                    value,
                  ) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Le titre est obligatoire';
                    }

                    return null;
                  },
                ),

                // ==================================================
                // MESSAGE
                // ==================================================

                const SizedBox(
                  height: 18,
                ),

                const Text(
                  'Contenu',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 7,
                ),

                TextFormField(
                  controller:
                      _messageController,
                  enabled: !_sending,
                  minLines: 4,
                  maxLines: 7,

                  decoration:
                      const InputDecoration(
                    hintText:
                        'Écrire le contenu de la notification...',
                    border:
                        OutlineInputBorder(),
                    alignLabelWithHint:
                        true,
                    prefixIcon: Padding(
                      padding:
                          EdgeInsets.only(
                        bottom: 65,
                      ),
                      child: Icon(
                        Icons
                            .message_outlined,
                      ),
                    ),
                  ),

                  validator: (
                    value,
                  ) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Le contenu est obligatoire';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _sending
              ? null
              : () {
                  Navigator.of(
                    context,
                  ).pop(false);
                },
          child: const Text(
            'ANNULER',
          ),
        ),

        FilledButton.icon(
          onPressed:
              _sending ? null : _send,

          icon: _sending
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  size: 18,
                ),

          label: Text(
            _sending
                ? 'Envoi...'
                : 'ENVOYER',
          ),
        ),
      ],
    );
  }
}