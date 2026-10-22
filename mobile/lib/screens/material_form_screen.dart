import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';

class MaterialFormScreen extends StatefulWidget {
  final int? id;

  const MaterialFormScreen({
    super.key,
    this.id,
  });

  bool get isEdit => id != null;

  @override
  State<MaterialFormScreen> createState() =>
      _MaterialFormScreenState();
}

class _MaterialFormScreenState
    extends State<MaterialFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nom = TextEditingController();
  final _marque = TextEditingController();
  final _modele = TextEditingController();
  final _numeroSerie = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _parents = [];

  int? _categorie;
  int? _kitParentId;

  String _etat = 'bon';
  String _statut = 'dispo';

  bool _loading = false;
  bool _loadingData = false;
  bool _loadingParents = true;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      _load();
    } else {
      _loadCategories();
      _loadParents();
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _marque.dispose();
    _modele.dispose();
    _numeroSerie.dispose();

    super.dispose();
  }

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  Future<void> _loadCategories() async {
    try {
      final data = await Api.get(
        '/categories/',
        cache: false,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _categories =
            data is List ? data : [];
      });
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e.toString(),
        );
      }
    }
  }

  Future<void> _loadParents() async {
    try {
      final data = await Api.get(
        '/materiels/',
        cache: false,
      );

      if (!mounted) {
        return;
      }

      List<dynamic> all = [];

      if (data is List) {
        all = data;
      } else if (data is Map &&
          data['results'] is List) {
        all = data['results'];
      }

      final parents = all.where((item) {
        if (item is! Map) {
          return false;
        }

        /*
         * Un matériel sans kit_parent
         * est considéré comme parent.
         */
        return item['kit_parent'] == null;
      }).toList();

      /*
       * En modification, il ne faut pas proposer
       * le matériel lui-même comme son propre parent.
       */
      final filtered = parents.where((item) {
        final id = _toInt(item['id']);

        return id != widget.id;
      }).toList();

      setState(() {
        _parents = filtered;
        _loadingParents = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingParents = false;
      });

      toast(
        context,
        'Impossible de charger les kits parents : $e',
      );
    }
  }

  Future<void> _load() async {
    setState(() {
      _loadingData = true;
    });

    try {
      final results = await Future.wait([
        Api.get(
          '/materiels/${widget.id}/',
          cache: false,
        ),
        Api.get(
          '/categories/',
          cache: false,
        ),
        Api.get(
          '/materiels/',
          cache: false,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final m = results[0];

      final categories =
          results[1] is List
              ? List<dynamic>.from(
                  results[1],
                )
              : <dynamic>[];

      List<dynamic> all = [];

      if (results[2] is List) {
        all = List<dynamic>.from(
          results[2],
        );
      } else if (results[2] is Map &&
          results[2]['results'] is List) {
        all = List<dynamic>.from(
          results[2]['results'],
        );
      }

      final parents = all.where((item) {
        if (item is! Map) {
          return false;
        }

        final id = _toInt(item['id']);

        return item['kit_parent'] == null &&
            id != widget.id;
      }).toList();

      setState(() {
        _categories = categories;
        _parents = parents;

        _nom.text =
            m['nom']?.toString() ?? '';

        _marque.text =
            m['marque']?.toString() ?? '';

        _modele.text =
            m['modele']?.toString() ?? '';

        _numeroSerie.text =
            m['numero_serie']?.toString() ?? '';

        _etat =
            m['etat']?.toString() ?? 'bon';

        _statut =
            m['statut']?.toString() ?? 'dispo';

        _categorie =
            _toInt(m['categorie']);

        /*
         * Le backend peut retourner soit :
         *
         * kit_parent: 5
         *
         * soit un objet selon le serializer.
         */
        final kitParent = m['kit_parent'];

        if (kitParent is Map) {
          _kitParentId =
              _toInt(kitParent['id']);
        } else {
          _kitParentId =
              _toInt(kitParent);
        }

        _loadingData = false;
        _loadingParents = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingData = false;
        _loadingParents = false;
      });

      toast(
        context,
        e.toString(),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categorie == null) {
      toast(
        context,
        'Sélectionnez une catégorie.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    final body = <String, dynamic>{
      'nom': _nom.text.trim(),
      'categorie': _categorie,
      'marque': _marque.text.trim(),
      'modele': _modele.text.trim(),
      'numero_serie': _numeroSerie.text.trim(),
      'etat': _etat,
      'statut': _statut,
      'kit_parent': _kitParentId,
    };

    try {
      dynamic result;

      if (widget.isEdit) {
        result = await Api.patch(
          '/materiels/${widget.id}/',
          body,
        );
      } else {
        result = await Api.post(
          '/materiels/',
          body,
        );
      }

      if (!mounted) {
        return;
      }

      toast(
        context,
        widget.isEdit
            ? 'Matériel modifié avec succès.'
            : 'Matériel ajouté avec succès.',
      );

      Navigator.pop(
        context,
        result,
      );
    } catch (e) {
      if (mounted) {
        toast(
          context,
          e.toString(),
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

  InputDecoration _decoration(
    String label, {
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon:
          icon == null ? null : Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  Widget _kitParentField() {
    if (_loadingParents) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: LinearProgressIndicator(),
      );
    }

    return DropdownButtonFormField<int?>(
      initialValue: _kitParentId,
      decoration: const InputDecoration(
        labelText: 'Kit Parent',
        prefixIcon: Icon(
          Icons.account_tree_outlined,
        ),
        border: OutlineInputBorder(),
        helperText:
            'Aucun = matériel principal',
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text(
            'Aucun — matériel principal',
          ),
        ),
        ..._parents.map((parent) {
          if (parent is! Map) {
            return const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'Matériel',
              ),
            );
          }

          final id =
              _toInt(parent['id']);

          if (id == null) {
            return const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'Matériel sans ID',
              ),
            );
          }

          final nom =
              parent['nom']?.toString() ??
                  'Matériel';

          final qr =
              parent['qr_code']?.toString() ??
                  '';

          return DropdownMenuItem<int?>(
            value: id,
            child: Text(
              qr.isEmpty
                  ? nom
                  : '$nom — $qr',
              overflow:
                  TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _kitParentId = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Modifier le matériel'
              : 'Ajouter un matériel',
        ),
      ),
      body: _loadingData
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.isEdit
                        ? 'Modifier le matériel'
                        : 'Nouveau matériel',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _nom,
                    decoration:
                        _decoration(
                      'Nom *',
                      icon: Icons
                          .inventory_2_outlined,
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.trim().isEmpty) {
                        return 'Le nom est obligatoire.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    initialValue:
                        _categories.any(
                      (c) =>
                          _toInt(c['id']) ==
                          _categorie,
                    )
                            ? _categorie
                            : null,
                    decoration:
                        _decoration(
                      'Catégorie *',
                      icon: Icons
                          .category_outlined,
                    ),
                    items: _categories
                        .map<
                            DropdownMenuItem<
                                int>?>(
                          (c) {
                            final id =
                                _toInt(
                              c['id'],
                            );

                            if (id == null) {
                              return null;
                            }

                            return DropdownMenuItem<
                                int>(
                              value: id,
                              child: Text(
                                c['nom']
                                        ?.toString() ??
                                    'Catégorie',
                              ),
                            );
                          },
                        )
                        .whereType<
                            DropdownMenuItem<
                                int>>()
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _categorie =
                            value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Sélectionnez une catégorie.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  _kitParentField(),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _marque,
                    decoration:
                        _decoration(
                      'Marque',
                      icon: Icons
                          .branding_watermark_outlined,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _modele,
                    decoration:
                        _decoration(
                      'Modèle',
                      icon: Icons
                          .devices_other_outlined,
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                        _numeroSerie,
                    decoration:
                        _decoration(
                      'N° de série',
                      icon: Icons
                          .confirmation_number_outlined,
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _etat,
                    decoration:
                        _decoration(
                      'État',
                      icon: Icons
                          .health_and_safety_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'neuf',
                        child:
                            Text('Neuf'),
                      ),
                      DropdownMenuItem(
                        value: 'bon',
                        child:
                            Text('Bon'),
                      ),
                      DropdownMenuItem(
                        value: 'use',
                        child:
                            Text('Usé'),
                      ),
                      DropdownMenuItem(
                        value: 'hs',
                        child:
                            Text('HS'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _etat = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: _statut,
                    decoration:
                        _decoration(
                      'Statut',
                      icon: Icons
                          .flag_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'dispo',
                        child: Text(
                          'Disponible',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'tournage',
                        child: Text(
                          'En tournage',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'emprunte',
                        child: Text(
                          'Emprunté',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'maintenance',
                        child: Text(
                          'En maintenance',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                            'hors_service',
                        child: Text(
                          'Hors service',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _statut = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed:
                          _loading
                              ? null
                              : _save,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .save_outlined,
                            ),
                      label: Text(
                        _loading
                            ? 'Enregistrement...'
                            : widget.isEdit
                                ? 'Enregistrer les modifications'
                                : 'Ajouter le matériel',
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}