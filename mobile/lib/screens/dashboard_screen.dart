import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../api.dart';
import 'inventory_screen.dart';
import 'projects_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDashboard();
  }

  Future<dynamic> _loadDashboard() async {
    return Api.get('/dashboard/');
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadDashboard();
    });

    try {
      await _future;
    } catch (_) {}
  }

  dynamic _get(
    dynamic data,
    String key, [
    dynamic fallback,
  ]) {
    if (data is Map) {
      return data[key] ?? fallback;
    }

    return fallback;
  }

  num _num(
    dynamic value, [
    num fallback = 0,
  ]) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      final normalized = value
          .replaceAll(' ', '')
          .replaceAll('€', '')
          .replaceAll(',', '.');

      return num.tryParse(normalized) ?? fallback;
    }

    return fallback;
  }

  int _int(
    dynamic value, [
    int fallback = 0,
  ]) {
    return _num(value, fallback).toInt();
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) {
      return value;
    }

    return [];
  }

  String _dayName(int day) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];

    return days[day - 1];
  }

  String _monthName(int month) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    return months[month - 1];
  }

  String _todayText() {
    final now = DateTime.now();

    return '${_dayName(now.weekday)} '
        '${now.day} '
        '${_monthName(now.month)}';
  }

  Map<String, dynamic> _normalize(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
                ),
              );
            }

            if (snapshot.hasError) {
              return _ErrorView(
                onRetry: _refresh,
              );
            }

            final data = _normalize(snapshot.data);

            return RefreshIndicator(
              color: colors.primary,
              backgroundColor: colors.surface,
              onRefresh: _refresh,
              child: _DashboardContent(
                data: data,
                todayText: _todayText(),
                onRefresh: _refresh,
                get: _get,
                intValue: _int,
                listValue: _list,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// DASHBOARD CONTENT
// ================================================================

class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final String todayText;
  final VoidCallback onRefresh;

  final dynamic Function(
    dynamic,
    String, [
    dynamic,
  ]) get;

  final int Function(
    dynamic, [
    int,
  ]) intValue;

  final List<dynamic> Function(dynamic) listValue;

  const _DashboardContent({
    required this.data,
    required this.todayText,
    required this.onRefresh,
    required this.get,
    required this.intValue,
    required this.listValue,
  });

  @override
  Widget build(BuildContext context) {
    final total = intValue(
      get(data, 'total', 0),
    );

    final rawStatuses = get(
      data,
      'par_statut',
      {},
    );

    final statuses = rawStatuses is Map
        ? Map<String, dynamic>.from(rawStatuses)
        : <String, dynamic>{};

    final disponibles = intValue(
      statuses['dispo'],
    );

    final tournage = intValue(
      statuses['tournage'],
    );

    final empruntes = intValue(
      statuses['emprunte'],
    );

    final maintenance = intValue(
      statuses['maintenance'],
    );

    final horsService = intValue(
      statuses['hors_service'],
    );

    // ============================================================
    // USER CONNECTÉ
    // ============================================================

    final userData = Api.user ?? <String, dynamic>{};

    final firstName =
        userData['first_name']?.toString().trim() ?? '';

    final lastName =
        userData['last_name']?.toString().trim() ?? '';

    String username = '$firstName $lastName'.trim();

    if (username.isEmpty) {
      username = userData['email']?.toString().trim() ?? '';
    }

    if (username.isEmpty) {
      username = userData['username']?.toString().trim() ?? '';
    }

    if (username.isEmpty) {
      username = 'Utilisateur';
    }

    // ============================================================
    // EMPRUNTS EN RETARD
    // ============================================================

    List<dynamic> empruntsEnRetard = listValue(
      get(
        data,
        'emprunts_en_retard',
        [],
      ),
    );

    if (empruntsEnRetard.isEmpty) {
      final oldRetards = listValue(
        get(
          data,
          'retards',
          [],
        ),
      );

      empruntsEnRetard = oldRetards.where((item) {
        if (item is! Map) {
          return false;
        }

        return item['type']?.toString() == 'emprunt';
      }).toList();
    }

    // ============================================================
    // TOURNAGES À PRÉPARER
    // ============================================================

    final tournagesAPreparer = listValue(
      get(
        data,
        'sorties_a_preparer',
        [],
      ),
    );

    // ============================================================
    // MAINTENANCE EN COURS
    // ============================================================

    final maintenanceEnCours = listValue(
      get(
        data,
        'maintenance_en_cours',
        [],
      ),
    );

    // ============================================================
    // RETOURS DU JOUR
    // ============================================================

    final retours = listValue(
      get(
        data,
        'retours_du_jour',
        [],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 32 : 20,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    username: username,
                    todayText: todayText,
                    onRefresh: onRefresh,
                  ),

                  const SizedBox(height: 24),

                  _LateReturnsCard(
                    emprunts: empruntsEnRetard,
                  ),

                  const SizedBox(height: 16),

                  _ActionCardsRow(
                    tournages: tournagesAPreparer,
                    maintenance: maintenanceEnCours,
                  ),

                  const SizedBox(height: 24),

                  _FleetCard(
                    total: total,
                    disponibles: disponibles,
                    tournage: tournage,
                    empruntes: empruntes,
                    maintenance: maintenance,
                    horsService: horsService,
                  ),

                  const SizedBox(height: 24),

                  _TodayReturnsCard(
                    returns: retours,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// HEADER
// ================================================================

class _Header extends StatelessWidget {
  final String username;
  final String todayText;
  final VoidCallback onRefresh;

  const _Header({
    required this.username,
    required this.todayText,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour $username',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                todayText,
                style: TextStyle(
                  fontSize: 24,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // const SizedBox(width: 16),
        // Material(
        //   color: colors.surface,
        //   elevation:
        //       Theme.of(context).brightness == Brightness.light
        //           ? 2
        //           : 0,
        //   shadowColor: Colors.black26,
        //   shape: const CircleBorder(),
        //   child: InkWell(
        //     onTap: onRefresh,
        //     customBorder: const CircleBorder(),
        //     child: const SizedBox(
        //       width: 82,
        //       height: 82,
        //       child: Icon(
        //         Icons.refresh_rounded,
        //         size: 36,
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }
}

// ================================================================
// EMPRUNTS EN RETARD
// ================================================================

class _LateReturnsCard extends StatelessWidget {
  final List<dynamic> emprunts;

  const _LateReturnsCard({
    required this.emprunts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final count = emprunts.length;
    final hasRetard = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: hasRetard
            ? () => _showDetails(context)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          decoration: BoxDecoration(
            color: hasRetard
                ? const Color(0xFFFFE8E8)
                : colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: hasRetard
                ? null
                : Border.all(
                    color: colors.outlineVariant,
                  ),
          ),
          child: Row(
            children: [
              Icon(
                hasRetard
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: hasRetard
                    ? const Color(0xFFE05252)
                    : colors.primary,
                size: 42,
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasRetard
                          ? '$count emprunt${count > 1 ? 's' : ''} en retard'
                          : 'Aucun emprunt en retard',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        color: hasRetard
                            ? const Color(0xFF8D2225)
                            : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasRetard
                          ? 'Touchez pour voir le détail'
                          : 'Tous les emprunts sont à jour',
                      style: TextStyle(
                        fontSize: 21,
                        color: hasRetard
                            ? const Color(0xFF8D2225)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRetard)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 38,
                  color: Color(0xFF8D2225),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height:
                MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Emprunts en retard',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${emprunts.length} emprunt${emprunts.length > 1 ? 's' : ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colors.error,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: emprunts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final raw = emprunts[index];

                      if (raw is! Map) {
                        return const SizedBox.shrink();
                      }

                      final item =
                          Map<String, dynamic>.from(raw);

                      return _LateEmpruntItem(
                        materiel:
                            item['materiel']?.toString() ?? '-',
                        emprunteur:
                            item['emprunteur']?.toString() ?? '-',
                        dateRetour:
                            item['date_retour_prevue']?.toString() ??
                                '',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ================================================================
// DETAIL EMPRUNT EN RETARD
// ================================================================

class _LateEmpruntItem extends StatelessWidget {
  final String materiel;
  final String emprunteur;
  final String dateRetour;

  const _LateEmpruntItem({
    required this.materiel,
    required this.emprunteur,
    required this.dateRetour,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colors.error,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materiel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Emprunteur : $emprunteur',
                ),
                const SizedBox(height: 4),
                Text(
                  'Retour prévu : ${_formatDate(dateRetour)}',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    if (value.isEmpty) {
      return '-';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      String two(int n) =>
          n.toString().padLeft(2, '0');

      return '${two(date.day)}/${two(date.month)}/${date.year} '
          '${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return value;
    }
  }
}

// ================================================================
// TOURNAGES + MAINTENANCE
// ================================================================

class _ActionCardsRow extends StatelessWidget {
  final List<dynamic> tournages;
  final List<dynamic> maintenance;

  const _ActionCardsRow({
    required this.tournages,
    required this.maintenance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            count: tournages.length,
            label: 'Tournage à préparer',
            color: const Color(0xFF2F6FDE),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectsScreen(
                    initialStatut: 'preparation',
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionCard(
            count: maintenance.length,
            label: 'Maintenance en cours',
            color: const Color(0xFFD97706),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InventoryScreen(
                    initialStatut: 'maintenance',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ================================================================
// ACTION CARD
// ================================================================

class _ActionCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.count,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(
                alpha: 0.25,
              ),
            ),
            boxShadow:
                Theme.of(context).brightness ==
                        Brightness.light
                    ? const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
          ),
          child: Row(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// FLEET CARD
// ================================================================

class _FleetCard extends StatelessWidget {
  final int total;
  final int disponibles;
  final int tournage;
  final int empruntes;
  final int maintenance;
  final int horsService;

  const _FleetCard({
    required this.total,
    required this.disponibles,
    required this.tournage,
    required this.empruntes,
    required this.maintenance,
    required this.horsService,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final wide =
        MediaQuery.of(context).size.width >= 700;

    final availablePercent = total > 0
        ? ((disponibles / total) * 100).round()
        : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        wide ? 34 : 26,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.25,
          ),
        ),
        boxShadow:
            Theme.of(context).brightness ==
                    Brightness.light
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Parc de matériel',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Text(
                '$total équipements',
                style: TextStyle(
                  fontSize: 21,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          wide
              ? Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _DonutChart(
                        total: total,
                        disponibles: disponibles,
                        tournage: tournage,
                        empruntes: empruntes,
                        maintenance: maintenance,
                        horsService: horsService,
                        percentage: availablePercent,
                      ),
                    ),
                    const SizedBox(width: 30),
                    Expanded(
                      flex: 6,
                      child: _Legend(
                        disponibles: disponibles,
                        tournage: tournage,
                        empruntes: empruntes,
                        maintenance: maintenance,
                        horsService: horsService,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _DonutChart(
                      total: total,
                      disponibles: disponibles,
                      tournage: tournage,
                      empruntes: empruntes,
                      maintenance: maintenance,
                      horsService: horsService,
                      percentage: availablePercent,
                    ),
                    const SizedBox(height: 28),
                    _Legend(
                      disponibles: disponibles,
                      tournage: tournage,
                      empruntes: empruntes,
                      maintenance: maintenance,
                      horsService: horsService,
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// ================================================================
// DONUT
// ================================================================

class _DonutChart extends StatelessWidget {
  final int total;
  final int disponibles;
  final int tournage;
  final int empruntes;
  final int maintenance;
  final int horsService;
  final int percentage;

  const _DonutChart({
    required this.total,
    required this.disponibles,
    required this.tournage,
    required this.empruntes,
    required this.maintenance,
    required this.horsService,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.of(context).size.width >= 700
            ? 280.0
            : 245.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              total: total,
              values: [
                disponibles,
                tournage,
                empruntes,
                maintenance,
                horsService,
              ],
              colors: const [
                Color(0xFF2E9E5B),
                Color(0xFF2F6FDE),
                Color(0xFF8050D8),
                Color(0xFFFF8618),
                Color(0xFFD94343),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                  color:
                      Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                'disponible',
                style: TextStyle(
                  fontSize: 21,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// DONUT PAINTER
// ================================================================

class _DonutPainter extends CustomPainter {
  final int total;
  final List<int> values;
  final List<Color> colors;

  _DonutPainter({
    required this.total,
    required this.values,
    required this.colors,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(
          size.width,
          size.height,
        ) /
        2;

    final strokeWidth = radius * 0.25;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    if (total <= 0) {
      final paint = Paint()
        ..color = const Color(0xFF7B8190)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(
        center,
        radius - strokeWidth / 2,
        paint,
      );

      return;
    }

    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      if (values[i] <= 0) {
        continue;
      }

      final sweepAngle =
          values[i] / total * math.pi * 2;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle,
        math.max(
          0,
          sweepAngle - 0.025,
        ),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(
    covariant _DonutPainter oldDelegate,
  ) {
    return oldDelegate.total != total ||
        oldDelegate.values != values;
  }
}

// ================================================================
// LEGEND
// ================================================================

class _Legend extends StatelessWidget {
  final int disponibles;
  final int tournage;
  final int empruntes;
  final int maintenance;
  final int horsService;

  const _Legend({
    required this.disponibles,
    required this.tournage,
    required this.empruntes,
    required this.maintenance,
    required this.horsService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LegendRow(
          color: const Color(0xFF2E9E5B),
          label: 'Disponibles',
          value: disponibles,
        ),
        const SizedBox(height: 20),
        _LegendRow(
          color: const Color(0xFF2F6FDE),
          label: 'En tournage',
          value: tournage,
        ),
        const SizedBox(height: 20),
        _LegendRow(
          color: const Color(0xFF8050D8),
          label: 'Empruntés',
          value: empruntes,
        ),
        const SizedBox(height: 20),
        _LegendRow(
          color: const Color(0xFFFF8618),
          label: 'Maintenance',
          value: maintenance,
        ),
        const SizedBox(height: 20),
        _LegendRow(
          color: const Color(0xFFD94343),
          label: 'Hors service',
          value: horsService,
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 21,
              color: colors.onSurface,
            ),
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// RETOURS DU JOUR
// ================================================================

class _TodayReturnsCard extends StatelessWidget {
  final List<dynamic> returns;

  const _TodayReturnsCard({
    required this.returns,
  });

  String _value(
    dynamic item,
    String key,
  ) {
    if (item is Map) {
      final value = item[key];

      if (value != null) {
        return value.toString();
      }
    }

    return '';
  }

  String _time(dynamic item) {
    final raw = _value(
      item,
      'date_retour_prevue',
    );

    if (raw.isEmpty) {
      return '--:--';
    }

    final match = RegExp(
      r'(\d{1,2}):(\d{2})',
    ).firstMatch(raw);

    if (match != null) {
      return '${match.group(1)!.padLeft(2, '0')}:'
          '${match.group(2)}';
    }

    try {
      final date = DateTime.parse(raw);

      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  String _secondaryText(dynamic item) {
    final projet = _value(
      item,
      'projet',
    );

    if (projet.isNotEmpty &&
        projet != 'null') {
      return projet;
    }

    final emprunteur = _value(
      item,
      'emprunteur',
    );

    if (emprunteur.isNotEmpty) {
      return emprunteur;
    }

    return 'Emprunt';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        30,
        30,
        30,
        28,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.25,
          ),
        ),
        boxShadow:
            Theme.of(context).brightness ==
                    Brightness.light
                ? const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Retours du jour',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(30),
                ),
                child: Text(
                  '${returns.length}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (returns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20,
              ),
              child: Center(
                child: Text(
                  'Aucun retour prévu aujourd’hui',
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...returns.asMap().entries.map(
              (entry) {
                final item = entry.value;

                final name = _value(
                  item,
                  'materiel',
                );

                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        entry.key == returns.length - 1
                            ? 0
                            : 18,
                  ),
                  child: _ReturnRow(
                    name: name.isEmpty
                        ? 'Matériel'
                        : name,
                    project: _secondaryText(item),
                    time: _time(item),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ================================================================
// RETURN ROW
// ================================================================

class _ReturnRow extends StatelessWidget {
  final String name;
  final String project;
  final String time;

  const _ReturnRow({
    required this.name,
    required this.project,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primary.withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.view_in_ar_outlined,
            color: colors.primary,
            size: 34,
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                project,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          time,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// ERROR
// ================================================================

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              'Impossible de charger le tableau de bord',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vérifiez la connexion au serveur Django.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}