import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'material_form_screen.dart';
import 'equipement_detail_screen.dart';

class MaterialDetailScreen extends StatefulWidget {
  final int id;

  const MaterialDetailScreen({
    super.key,
    required this.id,
  });

  @override
  State<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState
    extends State<MaterialDetailScreen> {
  late Future<List<dynamic>> _f = _fetch();

  // ============================================================
  // OUTILS JSON
  // ============================================================

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return List<dynamic>.from(value);
    }

    return <dynamic>[];
  }

  // ============================================================
  // CHARGEMENT
  // ============================================================

  Future<List<dynamic>> _fetch() {
    return Future.wait([
      Api.get('/materiels/${widget.id}/'),
      Api.get('/materiels/${widget.id}/historique/'),
    ]);
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _f = _fetch();
    });

    try {
      await _f;
    } catch (_) {
      // L'erreur sera affichée par Loader.
    }
  }

  // ============================================================
  // MODIFIER LE MATÉRIEL PARENT
  // ============================================================

  Future<void> _edit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialFormScreen(
          id: widget.id,
        ),
      ),
    );

    if (result != null && mounted) {
      await _reload();
    }
  }

  // ============================================================
  // SUPPRIMER LE MATÉRIEL PARENT
  // ============================================================

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text(
            'Supprimer le matériel ?',
          ),
          content: const Text(
            'Cette action est définitive. '
            'Le matériel sera supprimé de l’inventaire.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(c, true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await Api.delete(
        '/materiels/${widget.id}/',
      );

      if (!mounted) {
        return;
      }

      toast(
        context,
        'Matériel supprimé avec succès.',
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      toast(
        context,
        e.toString(),
      );
    }
  }

  // ============================================================
  // MODIFIER UN ÉQUIPEMENT
  // ============================================================

  Future<void> _editEquipment(
    int equipmentId,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialFormScreen(
          id: equipmentId,
        ),
      ),
    );

    if (result != null && mounted) {
      await _reload();
    }
  }

  // ============================================================
  // RETIRER UN ÉQUIPEMENT DU PARENT
  // ============================================================

  Future<void> _removeEquipment(
    int equipmentId,
    String equipmentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text(
            'Retirer du parent',
          ),
          content: Text(
            'Voulez-vous retirer "$equipmentName" '
            'de ce matériel parent ?\n\n'
            'L’équipement ne sera pas supprimé. '
            'Il redeviendra disponible dans l’inventaire principal.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c, true);
              },
              child: const Text('Retirer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      /*
       * Le backend traite DELETE sur un équipement enfant
       * comme un détachement :
       *
       *     kit_parent = None
       *
       * L'équipement n'est donc PAS supprimé.
       */

      await Api.delete(
        '/materiels/$equipmentId/',
      );

      if (!mounted) {
        return;
      }

      toast(
        context,
        '"$equipmentName" a été retiré du matériel parent.',
      );

      await _reload();
    } catch (e) {
      if (!mounted) {
        return;
      }

      toast(
        context,
        'Erreur lors du retrait : $e',
      );
    }
  }

  // ============================================================
  // RÉSERVER
  // ============================================================

  Future<void> _reserve() async {
    final projets = await guard(
      context,
      () => Api.get('/projets/'),
    );

    if (projets == null || !mounted) {
      return;
    }

    final projetsList = _asList(projets);

    final ouverts = projetsList
        .whereType<Map>()
        .map(
          (item) => _asMap(item),
        )
        .where(
          (p) {
            return p['statut'] == 'preparation' ||
                p['statut'] == 'en_cours';
          },
        )
        .toList();

    if (ouverts.isEmpty) {
      return toast(
        context,
        'Créez d\'abord un projet.',
      );
    }

    final p =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (c) {
        return ListView(
          children: [
            const ListTile(
              title: Text(
                'Ajouter à quel projet ?',
              ),
            ),
            for (final projet in ouverts)
              ListTile(
                title: Text(
                  projet['nom']?.toString() ?? '-',
                ),
                subtitle: Text(
                  '${fmt(
                    projet['date_debut'],
                    time: false,
                  )} → ${fmt(
                    projet['date_fin'],
                    time: false,
                  )}',
                ),
                onTap: () {
                  Navigator.pop(
                    c,
                    projet,
                  );
                },
              ),
          ],
        );
      },
    );

    if (p == null || !mounted) {
      return;
    }

    final projetId = p['id'];

    if (projetId == null) {
      return toast(
        context,
        'Identifiant du projet introuvable.',
      );
    }

    final r = await guard(
      context,
      () => Api.post(
        '/projets/$projetId/ajouter-materiel/',
        {
          'materiel_ids': [widget.id],
        },
      ),
    );

    if (r != null && mounted) {
      toast(
        context,
        'Ajouté à « ${p['nom'] ?? '-'} ».',
      );
    }

    await _reload();
  }

  // ============================================================
  // SIGNALER UN PROBLÈME
  // ============================================================

  Future<void> _report() async {
    String type = 'panne';

    final desc = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, set) {
            return AlertDialog(
              title: const Text(
                'Signaler un problème',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'panne',
                        child: Text(
                          'Panne / casse',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'revision',
                        child: Text(
                          'Révision',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'nettoyage',
                        child: Text(
                          'Nettoyage capteur',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'calibration',
                        child: Text(
                          'Calibration',
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        set(() {
                          type = v;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(c, false);
                  },
                  child: const Text(
                    'Annuler',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(c, true);
                  },
                  child: const Text(
                    'Envoyer',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    final description = desc.text.trim();

    desc.dispose();

    if (ok != true || !mounted) {
      return;
    }

    final r = await guard(
      context,
      () => Api.post(
        '/maintenances/',
        {
          'materiel': widget.id,
          'type': type,
          'description': description,
        },
      ),
    );

    if (r != null) {
      if (mounted) {
        toast(
          context,
          'Signalement enregistré : '
          'matériel passé en maintenance.',
        );
      }

      await _reload();
    }
  }

  // ============================================================
  // LIGNE INFORMATION
  // ============================================================

  Widget _row(
    String label,
    dynamic value,
  ) {
    final text =
        value == null ||
                value.toString().trim().isEmpty
            ? '-'
            : value.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT
  // ============================================================

  String _displayEtat(dynamic value) {
    switch (value?.toString()) {
      case 'neuf':
        return 'Neuf';

      case 'bon':
        return 'Bon';

      case 'use':
        return 'Usé';

      case 'hs':
        return 'HS';

      default:
        return value?.toString() ?? '-';
    }
  }

  // ============================================================
  // SOUS-TITRE ÉQUIPEMENT
  // ============================================================

  String _accessoireSubtitle(
    dynamic accessory,
  ) {
    final a = _asMap(accessory);

    final parts = <String>[];

    final categorie =
        a['categorie_nom']?.toString() ?? '';

    final marque =
        a['marque']?.toString() ?? '';

    final modele =
        a['modele']?.toString() ?? '';

    final numero =
        a['numero_serie']?.toString() ?? '';

    if (categorie.isNotEmpty) {
      parts.add(categorie);
    }

    if (marque.isNotEmpty) {
      parts.add(marque);
    }

    if (modele.isNotEmpty) {
      parts.add(modele);
    }

    if (numero.isNotEmpty) {
      parts.add('N° $numero');
    }

    if (parts.isEmpty) {
      return 'Équipement du kit';
    }

    return parts.join(' • ');
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fiche matériel',
        ),
        actions: [
          if (Api.isAdmin) ...[
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(
                Icons.edit_outlined,
              ),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(
                Icons.delete_outline,
              ),
              onPressed: _delete,
            ),
          ],
        ],
      ),

      // ==========================================================
      // CONTENU
      // ==========================================================

      body: Loader(
        future: _f,
        onRefresh: _reload,
        builder: (d) {
          // ------------------------------------------------------
          // MATÉRIEL PRINCIPAL
          // ------------------------------------------------------

          final m = d.isNotEmpty
              ? _asMap(d[0])
              : <String, dynamic>{};

          // ------------------------------------------------------
          // HISTORIQUE
          // ------------------------------------------------------

          final h = d.length > 1
              ? _asMap(d[1])
              : <String, dynamic>{};

          // ------------------------------------------------------
          // ÉQUIPEMENTS
          // ------------------------------------------------------

          final rawAccessoires =
              _asList(m['accessoires']);

          final accessoires = rawAccessoires
              .whereType<Map>()
              .map(
                (item) => _asMap(item),
              )
              .toList();

          final kitParentNom =
              m['kit_parent_nom'];

          // ------------------------------------------------------
          // HISTORIQUE RÉSERVATIONS
          // ------------------------------------------------------

          final reservations = _asList(
            h['reservations'],
          )
              .whereType<Map>()
              .map(
                (item) => _asMap(item),
              )
              .toList();

          // ------------------------------------------------------
          // HISTORIQUE MAINTENANCES
          // ------------------------------------------------------

          final maintenances = _asList(
            h['maintenances'],
          )
              .whereType<Map>()
              .map(
                (item) => _asMap(item),
              )
              .toList();

          // ------------------------------------------------------
          // BUILD
          // ------------------------------------------------------

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==================================================
              // NOM + STATUT
              // ==================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      m['nom']?.toString() ?? '-',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatutChip(
                    m['statut'],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ==================================================
              // QR CODE
              // ==================================================

              Center(
                child: Image.network(
                  '${Api.base}/materiels/${m['id']}/qr/',
                  headers: Api.headers,
                  width: 140,
                  height: 140,
                  errorBuilder: (
                    _,
                    __,
                    ___,
                  ) {
                    return const Icon(
                      Icons.qr_code_2,
                      size: 100,
                    );
                  },
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: SelectableText(
                  m['qr_code']?.toString() ?? '-',
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // INFORMATIONS
              // ==================================================

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row(
                        'Catégorie',
                        m['categorie_nom'],
                      ),
                      _row(
                        'Marque',
                        m['marque'],
                      ),
                      _row(
                        'Modèle',
                        m['modele'],
                      ),
                      _row(
                        'N° de série',
                        m['numero_serie'],
                      ),
                      _row(
                        'État',
                        _displayEtat(
                          m['etat'],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // KIT PARENT
              // ==================================================

              if (kitParentNom != null &&
                  kitParentNom
                      .toString()
                      .isNotEmpty) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_tree_outlined,
                    ),
                    title: const Text(
                      'Kit Parent',
                    ),
                    subtitle: Text(
                      kitParentNom.toString(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ==================================================
              // ÉQUIPEMENTS DU KIT
              // ==================================================

              if (accessoires.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Équipements du kit',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                            ),
                            CircleAvatar(
                              radius: 14,
                              child: Text(
                                '${accessoires.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ----------------------------------------
                        // LISTE DES ÉQUIPEMENTS
                        // ----------------------------------------

                        for (final a in accessoires)
                          Builder(
                            builder: (context) {
                              final equipmentId =
                                  int.tryParse(
                                a['id']?.toString() ?? '',
                              );

                              final equipmentName =
                                  a['nom']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ==
                                      true
                                  ? a['nom'].toString()
                                  : 'Équipement';

                              final qrCode =
                                  a['qr_code']
                                      ?.toString() ??
                                  '';

                              return ListTile(
                                contentPadding:
                                    EdgeInsets.zero,

                                leading:
                                    const CircleAvatar(
                                  child: Icon(
                                    Icons
                                        .extension_outlined,
                                  ),
                                ),

                                title: Text(
                                  equipmentName,
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),

                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    const SizedBox(
                                      height: 3,
                                    ),
                                    Text(
                                      _accessoireSubtitle(
                                        a,
                                      ),
                                    ),
                                    if (qrCode.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          top: 2,
                                        ),
                                        child: Text(
                                          'QR : $qrCode',
                                          style:
                                              Theme.of(
                                            context,
                                          )
                                                  .textTheme
                                                  .bodySmall,
                                        ),
                                      ),
                                  ],
                                ),

                                // --------------------------------
                                // MENU
                                // --------------------------------

                                trailing:
                                    Api.isAdmin &&
                                            equipmentId !=
                                                null
                                        ? PopupMenuButton<
                                            String>(
                                            tooltip:
                                                'Actions',
                                            onSelected:
                                                (value) async {
                                              if (value ==
                                                  'edit') {
                                                await _editEquipment(
                                                  equipmentId,
                                                );
                                              }

                                              if (value ==
                                                  'remove') {
                                                await _removeEquipment(
                                                  equipmentId,
                                                  equipmentName,
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) =>
                                                    const [
                                              PopupMenuItem<
                                                  String>(
                                                value:
                                                    'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .edit_outlined,
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          10,
                                                    ),
                                                    Text(
                                                      'Modifier',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<
                                                  String>(
                                                value:
                                                    'remove',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .link_off_outlined,
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          10,
                                                    ),
                                                    Text(
                                                      'Retirer du parent',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Icon(
                                            Icons
                                                .chevron_right,
                                          ),

                                // --------------------------------
                                // OUVRIR LE DÉTAIL
                                // --------------------------------

                                onTap:
                                    equipmentId == null
                                        ? null
                                        : () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) =>
                                                        EquipmentDetailScreen(
                                                  id:
                                                      equipmentId,
                                                ),
                                              ),
                                            );

                                            await _reload();
                                          },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],

              // ==================================================
              // ACTIONS
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _reserve,
                      icon: const Icon(
                        Icons.event_available,
                      ),
                      label: const Text(
                        'Réserver',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (Api.canWrite)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _report,
                        icon: const Icon(
                          Icons
                              .report_problem_outlined,
                        ),
                        label: const Text(
                          'Signaler',
                        ),
                      ),
                    ),
                ],
              ),

              const Divider(
                height: 32,
              ),

              // ==================================================
              // HISTORIQUE DES SORTIES
              // ==================================================

              Text(
                'Historique des sorties',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall,
              ),

              const SizedBox(height: 8),

              if (reservations.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  child: Text(
                    'Aucune sortie enregistrée.',
                  ),
                ),

              for (final r in reservations)
                ListTile(
                  dense: true,
                  title: Text(
                    '${r['projet']?.toString() ?? '-'} '
                    '(${r['statut']?.toString() ?? '-'})',
                  ),
                  subtitle: Text(
                    '${r['utilisateur']?.toString() ?? '-'} • '
                    '${fmt(r['sortie'])} → '
                    '${fmt(r['retour'])}',
                  ),
                ),

              const Divider(),

              // ==================================================
              // HISTORIQUE ENTRETIEN
              // ==================================================

              Text(
                'Historique d’entretien',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall,
              ),

              const SizedBox(height: 8),

              if (maintenances.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  child: Text(
                    'Aucun entretien enregistré.',
                  ),
                ),

              for (final x in maintenances)
                ListTile(
                  dense: true,
                  title: Text(
                    '${x['type']?.toString() ?? '-'} '
                    '— ${x['statut']?.toString() ?? '-'}',
                  ),
                  subtitle: Text(
                    '${x['date']?.toString() ?? '-'} • '
                    '${x['description']?.toString() ?? '-'}',
                  ),
                ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}