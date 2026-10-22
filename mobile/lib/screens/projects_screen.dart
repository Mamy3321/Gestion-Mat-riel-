import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../api.dart';
import '../widgets.dart';

class ProjectsScreen extends StatefulWidget {
  final String? initialStatut;

  const ProjectsScreen({
    super.key,
    this.initialStatut,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late Future<dynamic> _future = _fetch();

  late TabController _tabController;

  // ============================================================
  // INIT / DISPOSE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _initialTabIndex(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================================
  // ONGLET INITIAL
  // ============================================================

  int _initialTabIndex() {
    switch (widget.initialStatut) {
      case 'preparation':
        return 0;

      case 'en_cours':
        return 1;

      case 'termine':
      case 'historique':
        return 2;

      default:
        return 0;
    }
  }

  // ============================================================
  // DATE SIMPLE : YYYY-MM-DD
  // ============================================================

  String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final datePart =
        text.length >= 10 ? text.substring(0, 10) : text;

    final parsed = DateTime.tryParse(datePart);

    if (parsed == null) {
      return null;
    }

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  // ============================================================
  // STATUT AUTOMATIQUE DU PROJET
  // ============================================================

  String _automaticProjectStatus(
    dynamic dateDebut,
    dynamic dateFin,
  ) {
    final debut = _parseDateOnly(dateDebut);
    final fin = _parseDateOnly(dateFin);

    if (debut == null || fin == null) {
      return 'preparation';
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Avant le début
    if (today.isBefore(debut)) {
      return 'preparation';
    }

    // Pendant la période
    if (!today.isBefore(debut) &&
        !today.isAfter(fin)) {
      return 'en_cours';
    }

    // Après la date de fin
    return 'termine';
  }

  // ============================================================
  // LABEL STATUT
  // ============================================================

  String _projectStatusLabel(String status) {
    switch (status) {
      case 'preparation':
        return 'En préparation';

      case 'en_cours':
        return 'En cours';

      case 'termine':
        return 'Terminé';

      case 'historique':
        return 'Historique';

      case 'annule':
        return 'Annulé';

      default:
        return status.isEmpty ? 'Inconnu' : status;
    }
  }

  // ============================================================
  // DATE AFFICHAGE
  // ============================================================

  String _displayDate(dynamic value) {
    final date = _parseDateOnly(value);

    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _displayPeriod(
    dynamic debut,
    dynamic fin,
  ) {
    return '${_displayDate(debut)} → ${_displayDate(fin)}';
  }

  // ============================================================
  // FETCH
  // ============================================================

  Future<dynamic> _fetch() async {
    debugPrint(
      'PROJETS API => /projets/',
    );

    final data = await Api.get(
      '/projets/',
      cache: false,
    );

    return data;
  }

  // ============================================================
  // RELOAD
  // ============================================================

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = _fetch();
    });

    await _future.catchError((_) {});
  }

  // ============================================================
  // FILTRAGE PAR ONGLET
  // ============================================================

  List<Map<String, dynamic>> _filterProjects(
    List<Map<String, dynamic>> projects,
    int tabIndex,
  ) {
    return projects.where((project) {
      final automaticStatus =
          _automaticProjectStatus(
        project['date_debut'],
        project['date_fin'],
      );

      // --------------------------------------------------------
      // EN PRÉPARATION
      // --------------------------------------------------------

      if (tabIndex == 0) {
        return automaticStatus == 'preparation';
      }

      // --------------------------------------------------------
      // EN COURS
      // --------------------------------------------------------

      if (tabIndex == 1) {
        return automaticStatus == 'en_cours';
      }

      // --------------------------------------------------------
      // HISTORIQUE
      //
      // Tout projet terminé arrive automatiquement ici.
      // --------------------------------------------------------

      return automaticStatus == 'termine';
    }).toList();
  }

  // ============================================================
  // CRÉER UN PROJET
  // ============================================================

  Future<void> _create() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(
        now.year - 1,
        now.month,
        now.day,
      ),
      lastDate: DateTime(
        now.year + 2,
        now.month,
        now.day,
      ),
      helpText: 'Période du tournage',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (range == null || !mounted) {
      return;
    }

    final nom = TextEditingController();
    final lieu = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(
          'Nouveau projet',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nom,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nom du projet',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: lieu,
              decoration: const InputDecoration(
                labelText: 'Lieu',
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
              'Créer',
            ),
          ),
        ],
      ),
    );

    final projectName = nom.text.trim();
    final projectLieu = lieu.text.trim();

    nom.dispose();
    lieu.dispose();

    if (ok != true ||
        projectName.isEmpty ||
        !mounted) {
      return;
    }

    final debut = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );

    final fin = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );

    if (fin.isBefore(debut)) {
      toast(
        context,
        'La date de fin ne peut pas être avant la date de début.',
      );
      return;
    }

    final result = await guard(
      context,
      () => Api.post(
        '/projets/',
        {
          'nom': projectName,
          'lieu': projectLieu,
          'date_debut': _dateOnly(debut),
          'date_fin': _dateOnly(fin),
        },
      ),
    );

    if (result != null && mounted) {
      final id = result['id'];

      if (id == null) {
        toast(
          context,
          'Projet créé mais identifiant introuvable.',
        );

        await _reload();
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            id: id,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      await _reload();
    }
  }

  // ============================================================
  // PROJET CARD
  // ============================================================

  Widget _projectCard(
    BuildContext context,
    Map<String, dynamic> p,
  ) {
    final nom =
        p['nom']?.toString() ?? 'Projet';

    final lieu =
        p['lieu']?.toString() ?? '';

    final debut =
        p['date_debut'];

    final fin =
        p['date_fin'];

    final statut =
        _automaticProjectStatus(
      debut,
      fin,
    );

    final reservations =
        p['reservations'] is List
            ? p['reservations'] as List
            : const [];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: () async {
          final id = p['id'];

          if (id == null) {
            return;
          }

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProjectDetailScreen(
                id: id,
              ),
            ),
          );

          if (!mounted) {
            return;
          }

          await _reload();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // NOM + STATUT
              // --------------------------------------------------

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      nom,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  StatutChip(
                    statut,
                    label:
                        _projectStatusLabel(
                      statut,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // --------------------------------------------------
              // LIEU
              // --------------------------------------------------

              if (lieu.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lieu,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 8),

              // --------------------------------------------------
              // DATE
              // --------------------------------------------------

              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _displayPeriod(
                        debut,
                        fin,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // --------------------------------------------------
              // MATERIEL
              // --------------------------------------------------

              Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${reservations.length} matériel(s)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LISTE D'UN ONGLET
  // ============================================================

  Widget _buildTabList(
    BuildContext context,
    List<Map<String, dynamic>> projects,
  ) {
    if (projects.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 100,
          ),
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 60,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                'Aucun projet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          110,
        ),
        itemCount: projects.length,
        itemBuilder:
            (context, index) {
          return _projectCard(
            context,
            projects[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(
                Icons.schedule_outlined,
              ),
              text: 'Préparation',
            ),

            Tab(
              icon: Icon(
                Icons.play_circle_outline,
              ),
              text: 'En cours',
            ),

            Tab(
              icon: Icon(
                Icons.history_rounded,
              ),
              text: 'Historique',
            ),
          ],
        ),
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Projet',
        ),
      ),

      body: Loader(
        future: _future,
        onRefresh: _reload,
        builder: (data) {
          final projects = data is List
              ? data
                  .whereType<Map>()
                  .map(
                    (e) =>
                        Map<String, dynamic>.from(
                      e,
                    ),
                  )
                  .toList()
              : <Map<String, dynamic>>[];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTabList(
                context,
                _filterProjects(
                  projects,
                  0,
                ),
              ),

              _buildTabList(
                context,
                _filterProjects(
                  projects,
                  1,
                ),
              ),

              _buildTabList(
                context,
                _filterProjects(
                  projects,
                  2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==================================================================
// PROJECT DETAIL
// ==================================================================

class ProjectDetailScreen extends StatefulWidget {
  final int id;

  const ProjectDetailScreen({
    super.key,
    required this.id,
  });

  @override
  State<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState
    extends State<ProjectDetailScreen> {
  late Future<dynamic> _future = Api.get(
    '/projets/${widget.id}/',
    cache: false,
  );

  // ============================================================
  // DATE
  // ============================================================

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    final datePart =
        text.length >= 10
            ? text.substring(0, 10)
            : text;

    final parsed =
        DateTime.tryParse(datePart);

    if (parsed == null) {
      return null;
    }

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  String _dateOnly(DateTime date) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _displayDate(dynamic value) {
    final date =
        _parseDateOnly(value);

    if (date == null) {
      return '-';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // STATUT AUTOMATIQUE
  // ============================================================

  String _automaticProjectStatus(
    dynamic dateDebut,
    dynamic dateFin,
  ) {
    final debut =
        _parseDateOnly(dateDebut);

    final fin =
        _parseDateOnly(dateFin);

    if (debut == null || fin == null) {
      return 'preparation';
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (today.isBefore(debut)) {
      return 'preparation';
    }

    if (!today.isBefore(debut) &&
        !today.isAfter(fin)) {
      return 'en_cours';
    }

    return 'termine';
  }

  String _projectStatusLabel(
    String status,
  ) {
    switch (status) {
      case 'preparation':
        return 'En préparation';

      case 'en_cours':
        return 'En cours';

      case 'termine':
        return 'Terminé';

      case 'historique':
        return 'Historique';

      default:
        return status.isEmpty
            ? 'Inconnu'
            : status;
    }
  }

  // ============================================================
  // RELOAD
  // ============================================================

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _future = Api.get(
        '/projets/${widget.id}/',
        cache: false,
      );
    });

    await _future.catchError((_) {});
  }

  // ============================================================
  // MODIFIER PROJET
  // ============================================================

  Future<void> _edit(
    Map<String, dynamic> project,
  ) async {
    final nom =
        TextEditingController(
      text:
          project['nom']?.toString() ?? '',
    );

    final lieu =
        TextEditingController(
      text:
          project['lieu']?.toString() ?? '',
    );

    DateTime? start =
        _parseDateOnly(
      project['date_debut'],
    );

    DateTime? end =
        _parseDateOnly(
      project['date_fin'],
    );

    final result =
        await showDialog<bool>(
      context: context,
      builder: (c) =>
          StatefulBuilder(
        builder:
            (c, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Modifier le projet',
            ),

            content:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  TextField(
                    controller: nom,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Nom du projet',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  TextField(
                    controller: lieu,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Lieu',
                      border:
                          OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading:
                        const Icon(
                      Icons
                          .calendar_today_outlined,
                    ),
                    title:
                        const Text(
                      'Date de début',
                    ),
                    subtitle:
                        Text(
                      start == null
                          ? '-'
                          : _displayDate(
                              start,
                            ),
                    ),
                    onTap: () async {
                      final picked =
                          await showDatePicker(
                        context: c,
                        firstDate:
                            DateTime(2020),
                        lastDate:
                            DateTime.now()
                                .add(
                          const Duration(
                            days: 730,
                          ),
                        ),
                        initialDate:
                            start ??
                                DateTime.now(),
                      );

                      if (picked == null) {
                        return;
                      }

                      setDialogState(() {
                        start = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );

                        if (end != null &&
                            end!.isBefore(
                              start!,
                            )) {
                          end = start;
                        }
                      });
                    },
                  ),

                  ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading:
                        const Icon(
                      Icons.event_outlined,
                    ),
                    title:
                        const Text(
                      'Date de fin',
                    ),
                    subtitle:
                        Text(
                      end == null
                          ? '-'
                          : _displayDate(
                              end,
                            ),
                    ),
                    onTap: () async {
                      final picked =
                          await showDatePicker(
                        context: c,
                        firstDate:
                            start ??
                                DateTime(2020),
                        lastDate:
                            DateTime.now()
                                .add(
                          const Duration(
                            days: 730,
                          ),
                        ),
                        initialDate:
                            end ??
                                start ??
                                DateTime.now(),
                      );

                      if (picked == null) {
                        return;
                      }

                      setDialogState(() {
                        end = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    },
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  if (start != null &&
                      end != null)
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          10,
                        ),
                        color:
                            Theme.of(
                          context,
                        )
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .auto_awesome,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'Statut automatique : '
                              '${_projectStatusLabel(
                                _automaticProjectStatus(
                                  start,
                                  end,
                                ),
                              )}',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    c,
                    false,
                  );
                },
                child:
                    const Text(
                  'Annuler',
                ),
              ),

              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    c,
                    true,
                  );
                },
                child:
                    const Text(
                  'Enregistrer',
                ),
              ),
            ],
          );
        },
      ),
    );

    final projectName =
        nom.text.trim();

    final projectLieu =
        lieu.text.trim();

    nom.dispose();
    lieu.dispose();

    if (result != true ||
        !mounted) {
      return;
    }

    if (projectName.isEmpty ||
        start == null ||
        end == null) {
      toast(
        context,
        'Veuillez renseigner le nom et les dates.',
      );
      return;
    }

    final startOnly = DateTime(
      start!.year,
      start!.month,
      start!.day,
    );

    final endOnly = DateTime(
      end!.year,
      end!.month,
      end!.day,
    );

    if (endOnly.isBefore(startOnly)) {
      toast(
        context,
        'La date de fin ne peut pas être avant la date de début.',
      );
      return;
    }

    final updated =
        await guard(
      context,
      () => Api.patch(
        '/projets/${widget.id}/',
        {
          'nom': projectName,
          'lieu': projectLieu,
          'date_debut':
              _dateOnly(startOnly),
          'date_fin':
              _dateOnly(endOnly),
        },
      ),
    );

    if (updated != null &&
        mounted) {
      await _reload();

      if (!mounted) {
        return;
      }

      toast(
        context,
        'Projet modifié avec succès.',
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _delete(
    String nom,
  ) async {
    final ok =
        await showDialog<bool>(
      context: context,
      builder: (c) =>
          AlertDialog(
        title: const Text(
          'Supprimer le projet ?',
        ),
        content: Text(
          'Le projet "$nom" sera supprimé définitivement.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              c,
              false,
            ),
            child:
                const Text(
              'Annuler',
            ),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  Colors.red,
            ),
            onPressed: () =>
                Navigator.pop(
              c,
              true,
            ),
            child:
                const Text(
              'Supprimer',
            ),
          ),
        ],
      ),
    );

    if (ok != true ||
        !mounted) {
      return;
    }

    final result =
        await guard(
      context,
      () => Api.delete(
        '/projets/${widget.id}/',
      ),
    );

    if (result != null &&
        mounted) {
      Navigator.pop(
        context,
        true,
      );
    }
  }

  // ============================================================
  // ADD MATERIAL
  // ============================================================

  Future<void> _addMaterial() async {
    final data =
        await guard(
      context,
      () => Api.get(
        '/projets/${widget.id}/materiels-disponibles/',
        cache: false,
      ),
    );

    if (data == null ||
        !mounted) {
      return;
    }

    final list = data is List
        ? data
            .whereType<Map>()
            .map(
              (e) => Map<String, dynamic>.from(
                e,
              ),
            )
            .toList()
        : <Map<String, dynamic>>[];

    if (list.isEmpty) {
      toast(
        context,
        'Aucun matériel disponible pour cette période.',
      );
      return;
    }

    final selected =
        <int>{};

    final result =
        await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder:
              (c, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Ajouter du matériel',
              ),

              content:
                  SizedBox(
                width: 600,
                height: 500,
                child:
                    ListView.builder(
                  itemCount:
                      list.length,
                  itemBuilder:
                      (context, index) {
                    final m =
                        list[index];

                    final id =
                        int.tryParse(
                      m['id']
                              ?.toString() ??
                          '',
                    );

                    final nom =
                        m['nom']
                                ?.toString() ??
                            'Matériel';

                    final categorie =
                        m['categorie_nom']
                                ?.toString() ??
                            m['categorie']
                                ?.toString() ??
                            '';

                    final statut =
                        m['statut']
                                ?.toString() ??
                            '';

                    final disponible =
                        m['disponible'] !=
                            false;

                    final conflits =
                        m['conflits']
                                is List
                            ? m['conflits']
                                as List
                            : const [];

                    final disabled =
                        id == null ||
                            !disponible;

                    return CheckboxListTile(
                      value:
                          id != null &&
                              selected.contains(
                                id,
                              ),
                      enabled:
                          !disabled,
                      title:
                          Text(nom),
                      subtitle:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          if (categorie
                              .isNotEmpty)
                            Text(
                              categorie,
                            ),

                          if (statut
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 4,
                              ),
                              child:
                                  StatutChip(
                                statut,
                              ),
                            ),

                          if (conflits
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 6,
                              ),
                              child:
                                  Text(
                                _formatConflicts(
                                  conflits,
                                ),
                                style:
                                    TextStyle(
                                  color:
                                      Theme.of(
                                    context,
                                  )
                                          .colorScheme
                                          .error,
                                  fontSize:
                                      12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onChanged:
                          disabled
                              ? null
                              : (checked) {
                                  setDialogState(
                                    () {
                                      if (checked ==
                                          true) {
                                        selected.add(
                                          id,
                                        );
                                      } else {
                                        selected.remove(
                                          id,
                                        );
                                      }
                                    },
                                  );
                                },
                    );
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(
                    c,
                    false,
                  ),
                  child:
                      const Text(
                    'Annuler',
                  ),
                ),

                FilledButton(
                  onPressed:
                      selected.isEmpty
                          ? null
                          : () =>
                              Navigator.pop(
                            c,
                            true,
                          ),
                  child:
                      Text(
                    'Ajouter (${selected.length})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true ||
        !mounted) {
      return;
    }

    final resultPost =
        await guard(
      context,
      () => Api.post(
        '/projets/${widget.id}/ajouter-materiel/',
        {
          'materiel_ids':
              selected.toList(),
          'inclure_accessoires':
              true,
        },
      ),
    );

    if (resultPost != null &&
        mounted) {
      await _reload();

      if (!mounted) {
        return;
      }

      toast(
        context,
        'Matériel ajouté à la kit list.',
      );
    }
  }

  // ============================================================
  // CONFLITS
  // ============================================================

  String _formatConflicts(
    List conflicts,
  ) {
    final messages =
        <String>[];

    for (final conflict
        in conflicts) {
      if (conflict is! Map) {
        continue;
      }

      final type =
          conflict['type']
                  ?.toString() ??
              '';

      final projet =
          conflict['projet']
                  ?.toString() ??
              '';

      final debut =
          conflict['date_debut']
              ?.toString();

      final fin =
          conflict['date_fin']
              ?.toString();

      if (projet.isNotEmpty) {
        messages.add(
          '$type : $projet'
          '${debut != null ? ' (${_displayDate(debut)}' : ''}'
          '${fin != null ? ' → ${_displayDate(fin)})' : ''}',
        );
      } else {
        messages.add(
          type.isEmpty
              ? 'Conflit de disponibilité'
              : type,
        );
      }
    }

    if (messages.isEmpty) {
      return 'Conflit de disponibilité';
    }

    return messages.join('\n');
  }

  // ============================================================
  // CANCEL RESERVATION
  // ============================================================

  Future<void> _cancelReservation(
    int reservationId,
  ) async {
    final result =
        await guard(
      context,
      () => Api.post(
        '/reservations/$reservationId/annuler/',
      ),
    );

    if (result != null &&
        mounted) {
      await _reload();
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  Future<void> _pdf(
    String nom,
  ) async {
    final bytes =
        await guard(
      context,
      () => Api.getBytes(
        '/projets/${widget.id}/kit-list/',
      ),
    );

    if (bytes == null) {
      return;
    }

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'kit-list-$nom.pdf',
    );
  }

  // ============================================================
  // BUILD DETAIL
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Détail du projet',
        ),
        actions: [
          IconButton(
            tooltip:
                'Actualiser',
            onPressed:
                _reload,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: Loader(
        future:
            _future,
        onRefresh:
            _reload,
        builder: (data) {
          final project =
              Map<String,
                  dynamic>.from(
            data,
          );

          final nom =
              project['nom']
                      ?.toString() ??
                  'Projet';

          final lieu =
              project['lieu']
                      ?.toString() ??
                  '';

          final debut =
              project[
                  'date_debut'];

          final fin =
              project[
                  'date_fin'];

          final statut =
              _automaticProjectStatus(
            debut,
            fin,
          );

          final reservations =
              project['reservations']
                      is List
                  ? project[
                          'reservations']
                      as List
                  : const [];

          return ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              16,
              16,
              16,
              100,
            ),
            children: [
              // ==================================================
              // INFOS PROJET
              // ==================================================

              Card(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              nom,
                              style:
                                  Theme.of(
                                context,
                              )
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                            ),
                          ),

                          StatutChip(
                            statut,
                            label:
                                _projectStatusLabel(
                              statut,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      if (lieu
                          .isNotEmpty)
                        ListTile(
                          contentPadding:
                              EdgeInsets
                                  .zero,
                          leading:
                              const Icon(
                            Icons
                                .location_on_outlined,
                          ),
                          title:
                              const Text(
                            'Lieu',
                          ),
                          subtitle:
                              Text(
                            lieu,
                          ),
                        ),

                      ListTile(
                        contentPadding:
                            EdgeInsets
                                .zero,
                        leading:
                            const Icon(
                          Icons
                              .calendar_month_outlined,
                        ),
                        title:
                            const Text(
                          'Période',
                        ),
                        subtitle:
                            Text(
                          '${_displayDate(debut)} → ${_displayDate(fin)}',
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // KIT LIST
              // ==================================================

              Card(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                Text(
                              'Kit list',
                              style:
                                  Theme.of(
                                context,
                              )
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                            ),
                          ),

                          IconButton(
                            tooltip:
                                'Ajouter du matériel',
                            onPressed:
                                _addMaterial,
                            icon:
                                const Icon(
                              Icons
                                  .add_box_outlined,
                            ),
                          ),

                          IconButton(
                            tooltip:
                                'Exporter en PDF',
                            onPressed:
                                () =>
                                    _pdf(
                              nom,
                            ),
                            icon:
                                const Icon(
                              Icons
                                  .picture_as_pdf_outlined,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      if (reservations
                          .isEmpty)
                        const Padding(
                          padding:
                              EdgeInsets
                                  .symmetric(
                            vertical: 24,
                          ),
                          child:
                              Center(
                            child:
                                Text(
                              'Aucun matériel réservé.',
                            ),
                          ),
                        )
                      else
                        ...reservations.map(
                          (raw) {
                            final r =
                                Map<String,
                                    dynamic>.from(
                              raw,
                            );

                            final material =
                                r[
                                    'materiel'];

                            final materialMap =
                                material is Map
                                    ? Map<String,
                                        dynamic>.from(
                                        material,
                                      )
                                    : <String,
                                        dynamic>{};

                            final materialName =
                                materialMap[
                                            'nom']
                                        ?.toString() ??
                                    r[
                                            'materiel_nom']
                                        ?.toString() ??
                                    'Matériel';

                            final materialQr =
                                materialMap[
                                            'qr_code']
                                        ?.toString() ??
                                    '';

                            final reservationId =
                                int.tryParse(
                              r['id']
                                      ?.toString() ??
                                  '',
                            );

                            final reservationStatus =
                                r['statut']
                                        ?.toString() ??
                                    '';

                            final sortie =
                                r[
                                        'date_sortie_prevue']
                                    ?.toString();

                            final retour =
                                r[
                                        'date_retour_prevue']
                                    ?.toString();

                            final statusLabel =
                                _reservationStatusLabel(
                              reservationStatus,
                            );

                            return Card(
                              margin:
                                  const EdgeInsets
                                      .only(
                                bottom: 8,
                              ),
                              child:
                                  ListTile(
                                leading:
                                    const CircleAvatar(
                                  child:
                                      Icon(
                                    Icons
                                        .videocam_outlined,
                                  ),
                                ),

                                title:
                                    Text(
                                  materialName,
                                ),

                                subtitle:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    if (materialQr
                                        .isNotEmpty)
                                      Text(
                                        materialQr,
                                      ),

                                    const SizedBox(
                                      height: 4,
                                    ),

                                    Text(
                                      '${_displayDate(sortie)} → ${_displayDate(retour)}',
                                    ),

                                    if (statusLabel
                                        .isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets
                                                .only(
                                          top: 4,
                                        ),
                                        child:
                                            Text(
                                          statusLabel,
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                trailing:
                                    reservationId ==
                                            null
                                        ? null
                                        : PopupMenuButton<
                                            String>(
                                            onSelected:
                                                (value) {
                                              if (value ==
                                                  'cancel') {
                                                _cancelReservation(
                                                  reservationId,
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) =>
                                                    const [
                                              PopupMenuItem<
                                                  String>(
                                                value:
                                                    'cancel',
                                                child:
                                                    Text(
                                                  'Annuler la réservation',
                                                ),
                                              ),
                                            ],
                                          ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // ACTIONS PROJET
              // ==================================================

              Card(
                child:
                    Padding(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  child:
                      Column(
                    children: [
                      ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading:
                            const Icon(
                          Icons
                              .edit_outlined,
                        ),
                        title:
                            const Text(
                          'Modifier le projet',
                        ),
                        subtitle:
                            const Text(
                          'Nom, période et lieu',
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .chevron_right,
                        ),
                        onTap:
                            () async {
                          await _edit(
                            project,
                          );
                        },
                      ),

                      const Divider(),

                      ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading:
                            Icon(
                              Icons
                                  .delete_outline,
                              color:
                                  Theme.of(
                                context,
                              )
                                      .colorScheme
                                      .error,
                            ),
                        title:
                            Text(
                          'Supprimer le projet',
                          style:
                              TextStyle(
                            color:
                                Theme.of(
                              context,
                            )
                                        .colorScheme
                                        .error,
                          ),
                        ),
                        onTap:
                            () =>
                                _delete(
                          nom,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // RESERVATION STATUS
  // ============================================================

  String _reservationStatusLabel(
    String status,
  ) {
    switch (status) {
      case 'reservee':
        return 'Réservée';

      case 'sortie':
        return 'Sortie';

      case 'retournee':
        return 'Retournée';

      case 'annulee':
        return 'Annulée';

      default:
        return status;
    }
  }
}