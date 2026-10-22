import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'material_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  final String? initialStatut;

  const InventoryScreen({
    super.key,
    this.initialStatut,
  });

  @override
  State<InventoryScreen> createState() =>
      _InventoryScreenState();
}

class _InventoryScreenState
    extends State<InventoryScreen> {

  String _q = '';

  String? _statut;

  late Future<dynamic> _f;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // --------------------------------------------------------
    // Emprunté dia tsy aseho intsony ao amin'ny Inventaire.
    // Raha avy amin'ny Dashboard miaraka amin'ny "emprunte"
    // dia averina amin'ny "Tous".
    // --------------------------------------------------------

    if (widget.initialStatut == 'emprunte') {
      _statut = null;
    } else {
      _statut = widget.initialStatut;
    }

    _f = _fetch();
  }

  // ==========================================================
  // FETCH
  // ==========================================================

  Future<dynamic> _fetch() {

    final qs = <String>[];

    qs.add(
      'root=true',
    );

    // --------------------------------------------------------
    // RECHERCHE
    // --------------------------------------------------------

    if (_q.trim().isNotEmpty) {
      qs.add(
        'search=${Uri.encodeQueryComponent(
          _q.trim(),
        )}',
      );
    }

    // --------------------------------------------------------
    // FILTRE STATUT
    // --------------------------------------------------------

    if (_statut != null &&
        _statut!.isNotEmpty &&
        _statut != 'emprunte') {

      qs.add(
        'statut=${Uri.encodeQueryComponent(
          _statut!,
        )}',
      );
    }

    // --------------------------------------------------------
    // URL FINALE
    // --------------------------------------------------------

    final path =
        '/materiels/?${qs.join('&')}';

    debugPrint(
      'INVENTAIRE API => $path',
    );

    return Api.get(
      path,
      cache: false,
    );
  }

  // ==========================================================
  // RELOAD
  // ==========================================================

  Future<void> _reload() async {

    final future = _fetch();

    setState(() {
      _f = future;
    });

    try {
      await future;
    } catch (_) {
    }
  }

  // ==========================================================
  // SELECT STATUT
  // ==========================================================

  void _selectStatut(
    String? statut,
  ) {

    // --------------------------------------------------------
    // Emprunté tsy azo fidiana ao amin'ny Inventaire
    // --------------------------------------------------------

    if (statut == 'emprunte') {
      return;
    }

    setState(() {
      _statut = statut;
      _f = _fetch();
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(

      // ======================================================
      // APP BAR
      // ======================================================

      appBar: AppBar(
        title: Text(
          _statut == null
              ? 'Inventaire'
              : statutLabels[_statut]
                    ?? 'Inventaire',
        ),
      ),

      // ======================================================
      // BODY
      // ======================================================

      body: Column(
        children: [

          // ==================================================
          // RECHERCHE
          // ==================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              8,
              12,
              0,
            ),

            child: TextField(

              decoration:
                  const InputDecoration(
                prefixIcon:
                    Icon(Icons.search),

                hintText:
                    'Nom, marque, n° de série, code…',

                border:
                    OutlineInputBorder(),
              ),

              onSubmitted: (value) {

                setState(() {

                  _q = value.trim();

                  _f = _fetch();
                });
              },
            ),
          ),

          // ==================================================
          // FILTRES STATUT
          // ==================================================

          SingleChildScrollView(

            scrollDirection:
                Axis.horizontal,

            padding:
                const EdgeInsets.all(8),

            child: Row(
              children: [

                // --------------------------------------------
                // TOUS
                // --------------------------------------------

                Padding(
                  padding:
                      const EdgeInsets.only(
                    right: 6,
                  ),

                  child: ChoiceChip(

                    label:
                        const Text('Tous'),

                    selected:
                        _statut == null,

                    onSelected: (_) {

                      _selectStatut(
                        null,
                      );
                    },
                  ),
                ),

                // --------------------------------------------
                // STATUTS
                // --------------------------------------------
                // "emprunte" est volontairement exclu.
                // Il est géré dans le menu Emprunts.
                // --------------------------------------------

                for (final entry
                    in statutLabels.entries
                        .where(
                          (entry) =>
                              entry.key != 'emprunte',
                        ))

                  Padding(
                    padding:
                        const EdgeInsets.only(
                      right: 6,
                    ),

                    child: ChoiceChip(

                      label:
                          Text(entry.value),

                      selected:
                          _statut == entry.key,

                      onSelected: (_) {

                        _selectStatut(
                          entry.key,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ==================================================
          // LISTE
          // ==================================================

          Expanded(

            child: Loader(

              future: _f,

              onRefresh: _reload,

              builder: (data) {

                final items =
                    List<dynamic>.from(
                  data,
                );

                // ------------------------------------------
                // AUCUN RESULTAT
                // ------------------------------------------

                if (items.isEmpty) {

                  return ListView(
                    children: const [

                      SizedBox(
                        height: 80,
                      ),

                      Center(
                        child: Text(
                          'Aucun matériel',
                        ),
                      ),
                    ],
                  );
                }

                // ------------------------------------------
                // LISTE DES MATERIELS PARENTS
                // ------------------------------------------

                return ListView.separated(

                  padding:
                      const EdgeInsets.only(
                    bottom: 30,
                  ),

                  itemCount:
                      items.length,

                  separatorBuilder:
                      (_, __) =>
                          const Divider(
                    height: 1,
                  ),

                  itemBuilder:
                      (context, index) {

                    final m =
                        items[index];

                    // --------------------------------------
                    // ID
                    // --------------------------------------

                    final materialId =
                        m['id'] is num
                            ? (m['id'] as num)
                                .toInt()
                            : int.tryParse(
                                  m['id']
                                      .toString(),
                                );

                    // --------------------------------------
                    // STATUT
                    // --------------------------------------

                    final statut =
                        m['statut']
                                ?.toString()
                            ?? '';

                    // --------------------------------------
                    // NOM
                    // --------------------------------------

                    final nom =
                        m['nom']
                                ?.toString()
                            ?? '';

                    // --------------------------------------
                    // CATEGORIE
                    // --------------------------------------

                    final categorie =
                        m['categorie_nom']
                                ?.toString()
                            ?? '';

                    // --------------------------------------
                    // MARQUE
                    // --------------------------------------

                    final marque =
                        m['marque']
                                ?.toString()
                            ?? '';

                    // --------------------------------------
                    // MODELE
                    // --------------------------------------

                    final modele =
                        m['modele']
                                ?.toString()
                            ?? '';

                    // --------------------------------------
                    // SOUS-TITRE
                    // --------------------------------------

                    final details =
                        [
                          categorie,
                          marque,
                          modele,
                        ]
                            .where(
                              (e) =>
                                  e.trim().isNotEmpty,
                            )
                            .join(' • ');

                    // --------------------------------------
                    // MATERIAL CARD
                    // --------------------------------------

                    return ListTile(

                      leading:
                          CircleAvatar(

                        backgroundColor:
                            statutColor(
                              statut,
                            ).withValues(
                              alpha: .15,
                            ),

                        child: Icon(
                          Icons
                              .videocam_outlined,

                          color:
                              statutColor(
                            statut,
                          ),
                        ),
                      ),

                      title:
                          Text(nom),

                      subtitle:
                          Text(details),

                      trailing:
                          StatutChip(
                        statut,
                      ),

                      // ------------------------------------
                      // DETAIL
                      // ------------------------------------

                      onTap: materialId == null
                          ? null
                          : () async {

                              await Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) =>
                                      MaterialDetailScreen(
                                    id: materialId,
                                  ),
                                ),
                              );

                              _reload();
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}