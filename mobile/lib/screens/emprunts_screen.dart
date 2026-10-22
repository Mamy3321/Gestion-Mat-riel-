import 'package:flutter/material.dart';

import '../api.dart';

class EmpruntsScreen extends StatefulWidget {
  const EmpruntsScreen({super.key});

  @override
  State<EmpruntsScreen> createState() => _EmpruntsScreenState();
}

class _EmpruntsScreenState extends State<EmpruntsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = false;
  List<dynamic> _emprunts = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    _loadEmprunts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHARGER LES EMPRUNTS
  // ============================================================

  Future<void> _loadEmprunts() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await Api.get(
        '/emprunts/',
        cache: false,
      );

      if (!mounted) return;

      if (result is List) {
        setState(() {
          _emprunts = List<dynamic>.from(result);
        });
      } else if (result is Map && result['results'] is List) {
        setState(() {
          _emprunts = List<dynamic>.from(
            result['results'] as List,
          );
        });
      } else {
        setState(() {
          _emprunts = [];
        });
      }
    } catch (e) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors du chargement des emprunts : $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // VERIFIER SI LE MATERIEL EST RACINE
  // ============================================================

  bool _isRootMaterial(Map<String, dynamic> item) {
    final kitParent = item['kit_parent'];

    if (kitParent == null) {
      return true;
    }

    if (kitParent is String && kitParent.trim().isEmpty) {
      return true;
    }

    return false;
  }

  // ============================================================
  // VERIFIER SI LE MATERIEL EST DISPONIBLE
  // ============================================================

  bool _isAvailableMaterial(Map<String, dynamic> item) {
    final statut = item['statut']
        ?.toString()
        .trim()
        .toLowerCase();

    return statut == 'dispo' && _isRootMaterial(item);
  }

  // ============================================================
  // NORMALISER LA LISTE DES MATERIELS
  // ============================================================

  List<Map<String, dynamic>> _normalizeMaterials(dynamic result) {
    List<dynamic> rawList = [];

    if (result is List) {
      rawList = result;
    } else if (result is Map && result['results'] is List) {
      rawList = result['results'] as List;
    }

    final materials = <Map<String, dynamic>>[];

    for (final item in rawList) {
      if (item is! Map) {
        continue;
      }

      final material = Map<String, dynamic>.from(item);

      // ========================================================
      // IMPORTANT :
      // seuls les matériels racines et disponibles sont acceptés
      // ========================================================

      if (!_isAvailableMaterial(material)) {
        continue;
      }

      materials.add(material);
    }

    // Tri alphabétique
    materials.sort((a, b) {
      final nameA = (a['nom'] ?? '').toString().toLowerCase();
      final nameB = (b['nom'] ?? '').toString().toLowerCase();

      return nameA.compareTo(nameB);
    });

    return materials;
  }

  // ============================================================
  // CREER UN EMPRUNT
  // ============================================================

  Future<void> _create() async {
    try {
      final result = await Api.get(
        '/materiels/',
        cache: false,
      );

      final materials = _normalizeMaterials(result);

      if (!mounted) return;

      if (materials.isEmpty) {
        final messenger = ScaffoldMessenger.of(context);

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun matériel autonome disponible pour un emprunt.',
            ),
          ),
        );

        return;
      }

      await _showCreateDialog(materials);
    } catch (e) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de charger les matériels : $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DIALOG NOUVEL EMPRUNT
  // ============================================================

  Future<void> _showCreateDialog(
    List<Map<String, dynamic>> materials,
  ) async {
    Map<String, dynamic>? selectedMaterial;

    final motifController = TextEditingController();
    final montantController = TextEditingController();
    final notesController = TextEditingController();

    DateTime? dateDepart;
    DateTime? dateRetour;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
              context,
              setDialogState,
            ) {
              return AlertDialog(
                title: const Text(
                  'Nouvel emprunt',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================================================
                        // MATERIEL
                        // ==================================================

                        DropdownButtonFormField<
                            Map<String, dynamic>>(
                          initialValue: selectedMaterial,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Matériel',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.inventory_2_outlined,
                            ),
                          ),
                          items: materials.map((material) {
                            final nom =
                                (material['nom'] ?? 'Matériel')
                                    .toString();

                            final marque =
                                (material['marque'] ?? '')
                                    .toString()
                                    .trim();

                            final modele =
                                (material['modele'] ?? '')
                                    .toString()
                                    .trim();

                            String label = nom;

                            if (marque.isNotEmpty) {
                              label += ' — $marque';
                            }

                            if (modele.isNotEmpty &&
                                modele != marque) {
                              label += ' $modele';
                            }

                            return DropdownMenuItem<
                                Map<String, dynamic>>(
                              value: material,
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMaterial = value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // MOTIF
                        // ==================================================

                        TextField(
                          controller: motifController,
                          decoration: const InputDecoration(
                            labelText: 'Motif',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.description_outlined,
                            ),
                          ),
                          maxLines: 2,
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // DATE DEPART
                        // ==================================================

                        InkWell(
                          onTap: () async {
                            final now = DateTime.now();

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dateDepart ?? now,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (!context.mounted || picked == null) {
                              return;
                            }

                            setDialogState(() {
                              dateDepart = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                8,
                                0,
                              );

                              if (dateRetour != null &&
                                  dateRetour!.isBefore(
                                    dateDepart!,
                                  )) {
                                dateRetour = null;
                              }
                            });
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de départ',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.calendar_today_outlined,
                              ),
                            ),
                            child: Text(
                              dateDepart == null
                                  ? 'Sélectionner une date'
                                  : _formatDate(dateDepart!),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // DATE RETOUR
                        // ==================================================

                        InkWell(
                          onTap: () async {
                            final initial =
                                dateRetour ??
                                dateDepart ??
                                DateTime.now();

                            final firstDate =
                                dateDepart ?? DateTime(2020);

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: firstDate,
                              lastDate: DateTime(2100),
                            );

                            if (!context.mounted || picked == null) {
                              return;
                            }

                            setDialogState(() {
                              dateRetour = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                18,
                                0,
                              );
                            });
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de retour prévue',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.event_available_outlined,
                              ),
                            ),
                            child: Text(
                              dateRetour == null
                                  ? 'Sélectionner une date'
                                  : _formatDate(dateRetour!),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // MONTANT
                        // ==================================================

                        TextField(
                          controller: montantController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.payments_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // NOTES
                        // ==================================================

                        TextField(
                          controller: notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.notes_outlined,
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text(
                      'Annuler',
                    ),
                  ),

                  // ======================================================
                  // CREER
                  // ======================================================

                  FilledButton.icon(
                    icon: const Icon(
                      Icons.add,
                    ),
                    label: const Text(
                      'Créer',
                    ),
                    onPressed: () async {
                      // ================================================
                      // VALIDATION MATERIEL
                      // ================================================

                      if (selectedMaterial == null) {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez sélectionner un matériel.',
                            ),
                          ),
                        );

                        return;
                      }

                      // ================================================
                      // VALIDATION DATE DEPART
                      // ================================================

                      if (dateDepart == null) {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez sélectionner la date de départ.',
                            ),
                          ),
                        );

                        return;
                      }

                      // ================================================
                      // VALIDATION DATE RETOUR
                      // ================================================

                      if (dateRetour == null) {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Veuillez sélectionner la date de retour.',
                            ),
                          ),
                        );

                        return;
                      }

                      // ================================================
                      // VALIDATION PERIODE
                      // ================================================

                      if (!dateRetour!.isAfter(dateDepart!)) {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'La date de retour doit être après la date de départ.',
                            ),
                          ),
                        );

                        return;
                      }

                      final material = selectedMaterial!;

                      // ================================================
                      // DOUBLE VERIFICATION KIT PARENT
                      // ================================================

                      if (!_isRootMaterial(material)) {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Cet équipement appartient déjà à un kit-parent et ne peut pas être emprunté séparément.',
                            ),
                          ),
                        );

                        return;
                      }

                      // ================================================
                      // DOUBLE VERIFICATION STATUT
                      // ================================================

                      final statut = material['statut']
                          ?.toString()
                          .trim()
                          .toLowerCase();

                      if (statut != 'dispo') {
                        if (!context.mounted) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ce matériel n’est plus disponible.',
                            ),
                          ),
                        );

                        return;
                      }

                      // ================================================
                      // PAYLOAD
                      // ================================================

                      final payload = <String, dynamic>{
                        'materiel': material['id'],
                        'motif': motifController.text.trim(),
                        'date_depart_prevue':
                            dateDepart!.toIso8601String(),
                        'date_retour_prevue':
                            dateRetour!.toIso8601String(),
                      };

                      final montant =
                          montantController.text.trim();

                      if (montant.isNotEmpty) {
                        payload['montant'] = montant;
                      }

                      final notes =
                          notesController.text.trim();

                      if (notes.isNotEmpty) {
                        payload['notes'] = notes;
                      }

                      // ================================================
                      // MESSAGE DU DIALOG
                      // ================================================

                      final messenger =
                          ScaffoldMessenger.of(context);

                      try {
                        await Api.post(
                          '/emprunts/',
                          payload,
                        );

                        if (!dialogContext.mounted) {
                          return;
                        }

                        Navigator.of(dialogContext).pop();

                        await _loadEmprunts();

                        if (!mounted) return;

                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Emprunt créé avec succès.',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!dialogContext.mounted) {
                          return;
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Erreur lors de la création de l’emprunt : $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      motifController.dispose();
      montantController.dispose();
      notesController.dispose();
    }
  }

  // ============================================================
  // RETOURNER UN EMPRUNT
  // ============================================================

  Future<void> _retourner(
    Map<String, dynamic> emprunt,
  ) async {
    final id = emprunt['id'];

    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Retour du matériel',
          ),
          content: const Text(
            'Confirmer le retour de ce matériel ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Annuler',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Confirmer',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await Api.post(
        '/emprunts/$id/return/',
        {},
      );

      if (!mounted) return;

      await _loadEmprunts();

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Matériel retourné avec succès.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors du retour : $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // FILTRER LES EMPRUNTS
  // ============================================================

  List<dynamic> _filterEmprunts(
    int tabIndex,
  ) {
    if (tabIndex == 0) {
      return _emprunts.where((item) {
        if (item is! Map) {
          return false;
        }

        final status = item['statut']
            ?.toString()
            .trim()
            .toLowerCase();

        return status == 'planifie' ||
            status == 'en_cours';
      }).toList();
    }

    if (tabIndex == 1) {
      return _emprunts.where((item) {
        if (item is! Map) {
          return false;
        }

        final status = item['statut']
            ?.toString()
            .trim()
            .toLowerCase();

        return status == 'en_retard';
      }).toList();
    }

    return _emprunts.where((item) {
      if (item is! Map) {
        return false;
      }

      final status = item['statut']
          ?.toString()
          .trim()
          .toLowerCase();

      return status == 'retourne' ||
          status == 'annule';
    }).toList();
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    return '$day/$month/$year';
  }

  String _formatApiDate(
    dynamic value,
  ) {
    if (value == null) {
      return '-';
    }

    try {
      final date = DateTime.parse(
        value.toString(),
      );

      return _formatDate(date);
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // NOM DU MATERIEL
  // ============================================================

  String _materialName(
    Map item,
  ) {
    final material = item['materiel'];

    if (material is Map) {
      final nom =
          material['nom']?.toString() ??
          'Matériel';

      final marque =
          material['marque']
                  ?.toString()
                  .trim() ??
              '';

      final modele =
          material['modele']
                  ?.toString()
                  .trim() ??
              '';

      String result = nom;

      if (marque.isNotEmpty) {
        result += ' — $marque';
      }

      if (modele.isNotEmpty &&
          modele != marque) {
        result += ' $modele';
      }

      return result;
    }

    return material?.toString() ??
        'Matériel';
  }

  // ============================================================
  // CARD EMPRUNT
  // ============================================================

  Widget _buildEmpruntCard(
    Map<String, dynamic> emprunt,
  ) {
    final statut =
        emprunt['statut'];

    final status =
        statut?.toString().trim().toLowerCase();

    final materialName =
        _materialName(emprunt);

    final utilisateur =
        emprunt['utilisateur'];

    String userName = '-';

    if (utilisateur is Map) {
      final firstName =
          utilisateur['first_name']
                  ?.toString()
                  .trim() ??
              '';

      final lastName =
          utilisateur['last_name']
                  ?.toString()
                  .trim() ??
              '';

      final username =
          utilisateur['username']
                  ?.toString()
                  .trim() ??
              '';

      userName =
          '$firstName $lastName'.trim();

      if (userName.isEmpty) {
        userName = username;
      }
    } else if (utilisateur != null) {
      userName = utilisateur.toString();
    }

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    materialName,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(
                  status,
                ),
              ],
            ),

            const SizedBox(height: 12),

            _infoRow(
              Icons.person_outline,
              'Utilisateur',
              userName,
            ),

            _infoRow(
              Icons.calendar_today_outlined,
              'Départ',
              _formatApiDate(
                emprunt['date_depart_prevue'],
              ),
            ),

            _infoRow(
              Icons.event_available_outlined,
              'Retour prévu',
              _formatApiDate(
                emprunt['date_retour_prevue'],
              ),
            ),

            if (emprunt['motif'] != null &&
                emprunt['motif']
                    .toString()
                    .trim()
                    .isNotEmpty)
              _infoRow(
                Icons.description_outlined,
                'Motif',
                emprunt['motif'].toString(),
              ),

            if (status == 'en_cours' ||
                status == 'en_retard' ||
                status == 'planifie')
              Align(
                alignment:
                    Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    _retourner(emprunt);
                  },
                  icon: const Icon(
                    Icons.assignment_return_outlined,
                  ),
                  label: const Text(
                    'Retourner',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _buildStatusChip(
    String? status,
  ) {
    String label;

    switch (status) {
      case 'planifie':
        label = 'Planifié';
        break;

      case 'en_cours':
        label = 'En cours';
        break;

      case 'en_retard':
        label = 'En retard';
        break;

      case 'retourne':
        label = 'Retourné';
        break;

      case 'annule':
        label = 'Annulé';
        break;

      default:
        label = 'Inconnu';
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // LIGNE INFORMATION
  // ============================================================

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LISTE DES EMPRUNTS
  // ============================================================

  Widget _buildList(
    int tabIndex,
  ) {
    final list =
        _filterEmprunts(tabIndex);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (list.isEmpty) {
      String message;

      switch (tabIndex) {
        case 0:
          message =
              'Aucun emprunt en cours.';
          break;

        case 1:
          message =
              'Aucun emprunt en retard.';
          break;

        default:
          message =
              'Aucun historique.';
      }

      return RefreshIndicator(
        onRefresh: _loadEmprunts,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 400,
              child: Center(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEmprunts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics:
            const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        itemBuilder: (
          context,
          index,
        ) {
          final item = list[index];

          if (item is! Map) {
            return const SizedBox.shrink();
          }

          return _buildEmpruntCard(
            Map<String, dynamic>.from(item),
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Theme.of(context)
                .scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  text: 'En cours',
                ),
                Tab(
                  text: 'En retard',
                ),
                Tab(
                  text: 'Historique',
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(0),
                _buildList(1),
                _buildList(2),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Nouvel emprunt',
        ),
      ),
    );
  }
}