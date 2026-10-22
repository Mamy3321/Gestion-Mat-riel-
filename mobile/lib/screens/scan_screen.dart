import 'package:flutter/material.dart';

import 'package:mobile_scanner/mobile_scanner.dart';



import '../api.dart';

import '../widgets.dart';

import 'material_detail_screen.dart';



class ScanScreen extends StatefulWidget {

  const ScanScreen({super.key});



  @override

  State<ScanScreen> createState() => _ScanScreenState();

}



class _ScanScreenState extends State<ScanScreen> {

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('Scanner QR'),

      ),

      body: SafeArea(

        child: Padding(

          padding: const EdgeInsets.all(20),

          child: Column(

            children: [

              const SizedBox(height: 20),



              const Icon(

                Icons.qr_code_scanner,

                size: 90,

              ),



              const SizedBox(height: 20),



              const Text(

                'Gestion par QR code',

                style: TextStyle(

                  fontSize: 24,

                  fontWeight: FontWeight.bold,

                ),

                textAlign: TextAlign.center,

              ),



              const SizedBox(height: 10),



              const Text(

                'Choisissez une action',

                style: TextStyle(

                  fontSize: 16,

                ),

                textAlign: TextAlign.center,

              ),



              const SizedBox(height: 35),



              // ============================================================

              // VÉRIFIER UN MATÉRIEL

              // ============================================================



              SizedBox(

                width: double.infinity,

                child: Card(

                  child: InkWell(

                    borderRadius: BorderRadius.circular(12),

                    onTap: () {

                      Navigator.push(

                        context,

                        MaterialPageRoute(

                          builder: (_) => const _VerifyMaterialQrScreen(),

                        ),

                      );

                    },

                    child: const Padding(

                      padding: EdgeInsets.all(20),

                      child: Row(

                        children: [

                          CircleAvatar(

                            radius: 28,

                            child: Icon(

                              Icons.qr_code_scanner,

                              size: 30,

                            ),

                          ),

                          SizedBox(width: 18),

                          Expanded(

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                Text(

                                  'Vérifier un matériel',

                                  style: TextStyle(

                                    fontSize: 18,

                                    fontWeight: FontWeight.bold,

                                  ),

                                ),

                                SizedBox(height: 6),

                                Text(

                                  'Scanner le QR code d’un matériel existant '

                                  'pour consulter sa fiche.',

                                ),

                              ],

                            ),

                          ),

                          Icon(Icons.chevron_right),

                        ],

                      ),

                    ),

                  ),

                ),

              ),



              const SizedBox(height: 15),



              // ============================================================

              // AJOUTER UN MATÉRIEL

              // ============================================================



              if (Api.isAdmin)

                SizedBox(

                  width: double.infinity,

                  child: Card(

                    child: InkWell(

                      borderRadius: BorderRadius.circular(12),

                      onTap: () {

                        Navigator.push(

                          context,

                          MaterialPageRoute(

                            builder: (_) => const _CreateMaterialScreen(),

                          ),

                        );

                      },

                      child: const Padding(

                        padding: EdgeInsets.all(20),

                        child: Row(

                          children: [

                            CircleAvatar(

                              radius: 28,

                              child: Icon(

                                Icons.add_box_outlined,

                                size: 30,

                              ),

                            ),

                            SizedBox(width: 18),

                            Expanded(

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Text(

                                    'Ajouter un matériel',

                                    style: TextStyle(

                                      fontSize: 18,

                                      fontWeight: FontWeight.bold,

                                    ),

                                  ),

                                  SizedBox(height: 6),

                                  Text(

                                    'Créer un nouveau matériel. '

                                    'Le QR code sera généré automatiquement.',

                                  ),

                                ],

                              ),

                            ),

                            Icon(Icons.chevron_right),

                          ],

                        ),

                      ),

                    ),

                  ),

                ),



              const Spacer(),



              // const Text(

              //   'Le QR code est généré automatiquement lors de '

              //   'l’enregistrement du matériel.',

              //   textAlign: TextAlign.center,

              // ),



              const SizedBox(height: 15),

            ],

          ),

        ),

      ),

    );

  }

}



// ============================================================================

// ÉCRAN : VÉRIFIER UN MATÉRIEL

// ============================================================================



class _VerifyMaterialQrScreen extends StatefulWidget {

  const _VerifyMaterialQrScreen();



  @override

  State<_VerifyMaterialQrScreen> createState() =>

      _VerifyMaterialQrScreenState();

}



class _VerifyMaterialQrScreenState

    extends State<_VerifyMaterialQrScreen> {

  bool _busy = false;



  final TextEditingController _manual = TextEditingController();



  @override

  void dispose() {

    _manual.dispose();

    super.dispose();

  }



  // --------------------------------------------------------------------------

  // TRAITEMENT DU QR

  // --------------------------------------------------------------------------



  Future<void> _handle(String code) async {

    final qr = code.trim();



    if (qr.isEmpty || _busy) {

      return;

    }



    setState(() {

      _busy = true;

    });



    try {

      final m = await Api.get(

        '/materiels/par-qr/?code=${Uri.encodeQueryComponent(qr)}',

        cache: false,

      );



      if (!mounted) {

        return;

      }



      await _showMaterialActions(qr, m);

    } on ApiException catch (e) {

      if (!mounted) {

        return;

      }



      if (e.code == 404) {

        await _showQrNotRegistered(qr);

      } else {

        toast(context, e.message);

      }

    } catch (_) {

      if (mounted) {

        toast(context, 'Réseau indisponible.');

      }

    } finally {

      if (mounted) {

        setState(() {

          _busy = false;

        });

      }

    }

  }



  // --------------------------------------------------------------------------

  // QR NON ENREGISTRÉ

  // --------------------------------------------------------------------------



  Future<void> _showQrNotRegistered(String code) async {

    await showDialog<void>(

      context: context,

      builder: (context) {

        return AlertDialog(

          icon: const Icon(

            Icons.qr_code_2,

            size: 45,

          ),

          title: const Text('QR non enregistré'),

          content: Text(

            'Aucun matériel ne correspond au QR code :\n\n$code',

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text('OK'),

            ),

          ],

        );

      },

    );

  }



  // --------------------------------------------------------------------------

  // ACTIONS DU MATÉRIEL TROUVÉ

  // --------------------------------------------------------------------------



  Future<void> _showMaterialActions(

    String code,

    dynamic material,

  ) async {

    if (!mounted) {

      return;

    }



    final action = await showModalBottomSheet<String>(

      context: context,

      builder: (context) {

        final nom = material is Map

            ? (material['nom'] ?? 'Matériel')

            : 'Matériel';



        return SafeArea(

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const SizedBox(height: 10),



              const Icon(

                Icons.check_circle,

                size: 42,

              ),



              const SizedBox(height: 8),



              Padding(

                padding: const EdgeInsets.symmetric(horizontal: 20),

                child: Text(

                  '$nom',

                  style: const TextStyle(

                    fontSize: 19,

                    fontWeight: FontWeight.bold,

                  ),

                  textAlign: TextAlign.center,

                ),

              ),



              const SizedBox(height: 4),



              Text(

                code,

                style: const TextStyle(

                  fontSize: 13,

                ),

              ),



              const SizedBox(height: 10),



              const Divider(),



              // Voir fiche

              ListTile(

                leading: const Icon(Icons.info_outline),

                title: const Text('Voir la fiche'),

                onTap: () {

                  Navigator.pop(context, 'fiche');

                },

              ),



              // Check-out / Check-in

              if (Api.canWrite) ...[

                ListTile(

                  leading: const Icon(Icons.outbox),

                  title: const Text('Check-out (sortie)'),

                  onTap: () {

                    Navigator.pop(context, 'out');

                  },

                ),

                ListTile(

                  leading: const Icon(Icons.move_to_inbox),

                  title: const Text('Check-in (retour)'),

                  onTap: () {

                    Navigator.pop(context, 'in');

                  },

                ),

              ],



              const SizedBox(height: 10),

            ],

          ),

        );

      },

    );



    if (!mounted || action == null) {

      return;

    }



    try {

      // ----------------------------------------------------------------------

      // VOIR LA FICHE

      // ----------------------------------------------------------------------



      if (action == 'fiche') {

        final id = material['id'];



        if (id == null) {

          toast(context, 'Identifiant du matériel introuvable.');

          return;

        }



        await Navigator.push(

          context,

          MaterialPageRoute(

            builder: (_) => MaterialDetailScreen(

              id: id,

            ),

          ),

        );



        return;

      }



      // ----------------------------------------------------------------------

      // CHECK-OUT / CHECK-IN

      // ----------------------------------------------------------------------



      final result = await Api.postQueued(

        '/reservations/scan/',

        {

          'qr_code': code,

          'action': action,

        },

      );



      if (!mounted) {

        return;

      }



      // Hors ligne

      if (result == null) {

        toast(

          context,

          'Hors ligne : action enregistrée, '

          'elle sera envoyée à la reconnexion.',

        );

        return;

      }



      final manquants = List.from(

        result['manquants'] ?? [],

      );



      await showDialog<void>(

        context: context,

        builder: (context) {

          final sortie = action == 'out';



          return AlertDialog(

            icon: Icon(

              manquants.isEmpty

                  ? Icons.check_circle

                  : Icons.warning_amber,

              size: 45,

            ),

            title: Text(

              sortie

                  ? 'Sortie enregistrée'

                  : 'Retour enregistré',

            ),

            content: Text(

              manquants.isEmpty

                  ? '${result['reservation']?['materiel_nom'] ?? ''}'

                    ' — '

                    '${result['reservation']?['projet_nom'] ?? ''}'

                  : 'Checklist : accessoires NON rendus :\n'

                    '• ${manquants.join('\n• ')}',

            ),

            actions: [

              TextButton(

                onPressed: () {

                  Navigator.pop(context);

                },

                child: const Text('OK'),

              ),

            ],

          );

        },

      );

    } on ApiException catch (e) {

      if (mounted) {

        toast(context, e.message);

      }

    } catch (_) {

      if (mounted) {

        toast(context, 'Réseau indisponible.');

      }

    }

  }



  // --------------------------------------------------------------------------

  // BUILD

  // --------------------------------------------------------------------------



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('Vérifier un matériel'),

      ),

      body: Column(

        children: [

          Expanded(

            child: Stack(

              children: [

                MobileScanner(

                  onDetect: (capture) {

                    if (_busy) {

                      return;

                    }



                    if (capture.barcodes.isEmpty) {

                      return;

                    }



                    final value =

                        capture.barcodes.first.rawValue;



                    if (value == null || value.trim().isEmpty) {

                      return;

                    }



                    _handle(value);

                  },

                  errorBuilder: (

                    context,

                    error,

                    child,

                  ) {

                    return const Center(

                      child: Padding(

                        padding: EdgeInsets.all(20),

                        child: Text(

                          'Caméra indisponible.\n\n'

                          'Vous pouvez saisir manuellement '

                          'le QR code ci-dessous.',

                          textAlign: TextAlign.center,

                        ),

                      ),

                    );

                  },

                ),



                if (_busy)

                  const Center(

                    child: CircularProgressIndicator(),

                  ),



                Positioned(

                  top: 20,

                  left: 20,

                  right: 20,

                  child: IgnorePointer(

                    child: Container(

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(

                        color: Colors.black54,

                        borderRadius: BorderRadius.circular(10),

                      ),

                      child: const Text(

                        'Placez le QR code dans la zone de scan',

                        textAlign: TextAlign.center,

                        style: TextStyle(

                          color: Colors.white,

                          fontSize: 15,

                        ),

                      ),

                    ),

                  ),

                ),

              ],

            ),

          ),



          // ------------------------------------------------------------------

          // SAISIE MANUELLE

          // ------------------------------------------------------------------



          Padding(

            padding: const EdgeInsets.all(12),

            child: Row(

              children: [

                Expanded(

                  child: TextField(

                    controller: _manual,

                    enabled: !_busy,

                    textInputAction: TextInputAction.done,

                    onSubmitted: (value) {

                      if (value.trim().isNotEmpty) {

                        _handle(value.trim());

                      }

                    },

                    decoration: const InputDecoration(

                      labelText: 'Saisie manuelle',

                      hintText: 'MAT-XXXX',

                      border: OutlineInputBorder(),

                      prefixIcon: Icon(

                        Icons.qr_code_2,

                      ),

                    ),

                  ),

                ),



                const SizedBox(width: 8),



                FilledButton(

                  onPressed: _busy

                      ? null

                      : () {

                          final code =

                              _manual.text.trim();



                          if (code.isNotEmpty) {

                            _handle(code);

                          }

                        },

                  child: const Text('OK'),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================================

// ÉCRAN : AJOUTER UN MATÉRIEL

// ============================================================================



class _CreateMaterialScreen extends StatefulWidget {

  const _CreateMaterialScreen();



  @override

  State<_CreateMaterialScreen> createState() =>

      _CreateMaterialScreenState();

}



class _CreateMaterialScreenState

    extends State<_CreateMaterialScreen> {

  final _formKey = GlobalKey<FormState>();



  // Champs

  final _nom = TextEditingController();

  final _marque = TextEditingController();

  final _modele = TextEditingController();

  final _numeroSerie = TextEditingController();

  final _dateAchat = TextEditingController();

  final _valeur = TextEditingController();

  final _valeurRemplacement = TextEditingController();

  final _fournisseur = TextEditingController();

  final _assuranceRef = TextEditingController();

  final _cycles = TextEditingController();

  final _cyclesMax = TextEditingController();



  bool _loading = false;

  bool _loadingCategories = true;



  List<dynamic> _categories = [];



  int? _categorieId;

  int? _kitParentId;



  String _etat = 'bon';

  String _statut = 'dispo';



  final bool _loueATiers = false;

  final bool _assure = false;



  @override

  void initState() {

    super.initState();



    _loadCategories();

  }



  @override

  void dispose() {

    _nom.dispose();

    _marque.dispose();

    _modele.dispose();

    _numeroSerie.dispose();

    _dateAchat.dispose();

    _valeur.dispose();

    _valeurRemplacement.dispose();

    _fournisseur.dispose();

    _assuranceRef.dispose();

    _cycles.dispose();

    _cyclesMax.dispose();



    super.dispose();

  }



  // --------------------------------------------------------------------------

  // CHARGER LES CATÉGORIES

  // --------------------------------------------------------------------------



  Future<void> _loadCategories() async {

    try {

      final response = await Api.get(

        '/categories/',

        cache: false,

      );



      if (!mounted) {

        return;

      }



      if (response is List) {

        setState(() {

          _categories = response;

          _loadingCategories = false;

        });

      } else if (response is Map &&

          response['results'] is List) {

        setState(() {

          _categories = response['results'];

          _loadingCategories = false;

        });

      } else {

        setState(() {

          _categories = [];

          _loadingCategories = false;

        });

      }

    } catch (e) {

      if (!mounted) {

        return;

      }



      setState(() {

        _loadingCategories = false;

      });



      toast(

        context,

        'Impossible de charger les catégories.',

      );

    }

  }

  // --------------------------------------------------------------------------
  // CRÉATION

  // --------------------------------------------------------------------------



  Future<void> _create() async {

    if (!_formKey.currentState!.validate()) {

      return;

    }



    if (_categorieId == null) {

      toast(

        context,

        'Veuillez sélectionner une catégorie.',

      );

      return;

    }



    setState(() {

      _loading = true;

    });



    try {

      final body = <String, dynamic>{

        'nom': _nom.text.trim(),

        'categorie': _categorieId,

        'marque': _marque.text.trim(),

        'modele': _modele.text.trim(),

        'numero_serie': _numeroSerie.text.trim(),

        'etat': _etat,

        'statut': _statut,

        'date_achat': _dateAchat.text.trim().isEmpty

            ? null

            : _dateAchat.text.trim(),

        'valeur': _numberOrZero(_valeur.text),

        'valeur_remplacement':

            _numberOrZero(_valeurRemplacement.text),

        'loue_a_tiers': _loueATiers,

        'fournisseur': _fournisseur.text.trim(),

        'assure': _assure,

        'assurance_ref': _assuranceRef.text.trim(),

        'cycles': _intOrZero(_cycles.text),

        'cycles_max': _nullableInt(_cyclesMax.text),

      };



      if (_kitParentId != null) {

        body['kit_parent'] = _kitParentId;

      }



      // IMPORTANT :

      // On ne met PAS qr_code ici.

      // Django le génère automatiquement dans Materiel.save().

      final result = await Api.post(

        '/materiels/',

        body,

      );



      if (!mounted) {

        return;

      }



      final qrCode = result is Map

          ? result['qr_code']?.toString()

          : null;



      await showDialog<void>(

        context: context,

        barrierDismissible: false,

        builder: (context) {

          return AlertDialog(

            icon: const Icon(

              Icons.check_circle,

              size: 50,

            ),

            title: const Text(

              'Matériel ajouté',

            ),

            content: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                const Text(

                  'Le matériel a été enregistré avec succès.',

                  textAlign: TextAlign.center,

                ),



                if (qrCode != null &&

                    qrCode.isNotEmpty) ...[

                  const SizedBox(height: 20),



                  const Text(

                    'QR code généré :',

                    style: TextStyle(

                      fontWeight: FontWeight.bold,

                    ),

                  ),



                  const SizedBox(height: 8),



                  Container(

                    width: double.infinity,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(

                      border: Border.all(),

                      borderRadius:

                          BorderRadius.circular(8),

                    ),

                    child: SelectableText(

                      qrCode,

                      textAlign: TextAlign.center,

                      style: const TextStyle(

                        fontSize: 18,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ),

                ],

              ],

            ),

            actions: [

              FilledButton(

                onPressed: () {

                  Navigator.pop(context);

                },

                child: const Text('OK'),

              ),

            ],

          );

        },

      );



      if (!mounted) {

        return;

      }



      Navigator.pop(context, result);

    } on ApiException catch (e) {

      if (mounted) {

        toast(

          context,

          e.message,

        );

      }

    } catch (_) {

      if (mounted) {

        toast(

          context,

          'Erreur lors de l’ajout du matériel.',

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



  // --------------------------------------------------------------------------

  // HELPERS

  // --------------------------------------------------------------------------



  double _numberOrZero(String value) {

    final v = value.trim();



    if (v.isEmpty) {

      return 0;

    }



    return double.tryParse(

          v.replaceAll(',', '.'),

        ) ??

        0;

  }



  int _intOrZero(String value) {

    final v = value.trim();



    if (v.isEmpty) {

      return 0;

    }



    return int.tryParse(v) ?? 0;

  }



  int? _nullableInt(String value) {

    final v = value.trim();



    if (v.isEmpty) {

      return null;

    }



    return int.tryParse(v);

  }



  // --------------------------------------------------------------------------

  // FIELD TEXT

  // --------------------------------------------------------------------------



  Widget _textField(

    TextEditingController controller, {

    required String label,

    String? hint,

    TextInputType? keyboardType,

    bool required = false,

  }) {

    return TextFormField(

      controller: controller,

      keyboardType: keyboardType,

      decoration: InputDecoration(

        labelText: label,

        hintText: hint,

        border: const OutlineInputBorder(),

      ),

      validator: required

          ? (value) {

              if (value == null ||

                  value.trim().isEmpty) {

                return 'Champ obligatoire';

              }



              return null;

            }

          : null,

    );

  }



  // --------------------------------------------------------------------------

  // DROPDOWN ÉTAT

  // --------------------------------------------------------------------------



  Widget _etatField() {

    return DropdownButtonFormField<String>(

      initialValue: _etat,

      decoration: const InputDecoration(

        labelText: 'État',

        border: OutlineInputBorder(),

      ),

      items: const [

        DropdownMenuItem(

          value: 'neuf',

          child: Text('Neuf'),

        ),

        DropdownMenuItem(

          value: 'bon',

          child: Text('Bon'),

        ),

        DropdownMenuItem(

          value: 'use',

          child: Text('Usé'),

        ),

        DropdownMenuItem(

          value: 'hs',

          child: Text('HS'),

        ),

      ],

      onChanged: (value) {

        if (value != null) {

          setState(() {

            _etat = value;

          });

        }

      },

    );

  }



  // --------------------------------------------------------------------------

  // DROPDOWN STATUT

  // --------------------------------------------------------------------------



  Widget _statutField() {

    return DropdownButtonFormField<String>(

      initialValue: _statut,

      decoration: const InputDecoration(

        labelText: 'Statut',

        border: OutlineInputBorder(),

      ),

      items: const [

        DropdownMenuItem(

          value: 'dispo',

          child: Text('Disponible'),

        ),

        DropdownMenuItem(

          value: 'tournage',

          child: Text('En tournage'),

        ),

        DropdownMenuItem(

          value: 'emprunte',

          child: Text('Emprunté'),

        ),

        DropdownMenuItem(

          value: 'maintenance',

          child: Text('En maintenance'),

        ),

        DropdownMenuItem(

          value: 'hors_service',

          child: Text('Hors service'),

        ),

      ],

      onChanged: (value) {

        if (value != null) {

          setState(() {

            _statut = value;

          });

        }

      },

    );

  }



  // --------------------------------------------------------------------------

  // DROPDOWN CATÉGORIE

  // --------------------------------------------------------------------------



  Widget _categorieField() {

    if (_loadingCategories) {

      return const InputDecorator(

        decoration: InputDecoration(

          labelText: 'Catégorie',

          border: OutlineInputBorder(),

        ),

        child: Row(

          children: [

            SizedBox(

              width: 18,

              height: 18,

              child: CircularProgressIndicator(

                strokeWidth: 2,

              ),

            ),

            SizedBox(width: 12),

            Text('Chargement...'),

          ],

        ),

      );

    }



    return DropdownButtonFormField<int>(

      initialValue: _categorieId,

      decoration: const InputDecoration(

        labelText: 'Catégorie',

        border: OutlineInputBorder(),

      ),

      items: _categories.map<DropdownMenuItem<int>>(

        (category) {

          final id = category['id'];



          final nom =

              category['nom']?.toString() ??

                  'Catégorie';



          return DropdownMenuItem<int>(

            value: id is int

                ? id

                : int.tryParse(id.toString()),

            child: Text(nom),

          );

        },

      ).toList(),

      onChanged: (value) {

        setState(() {

          _categorieId = value;

        });

      },

      validator: (value) {

        if (value == null) {

          return 'Catégorie obligatoire';

        }



        return null;

      },

    );

  }



  // --------------------------------------------------------------------------

  // BUILD FORM

  // --------------------------------------------------------------------------



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('Ajouter un matériel'),

      ),

      body: Form(

        key: _formKey,

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            // ---------------------------------------------------------------

            // INFORMATIONS PRINCIPALES

            // ---------------------------------------------------------------



            const Text(

              'Informations principales',

              style: TextStyle(

                fontSize: 19,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 15),



            _textField(

              _nom,

              label: 'Nom',

              required: true,

            ),



            const SizedBox(height: 12),



            _categorieField(),



            const SizedBox(height: 12),



            _textField(

              _marque,

              label: 'Marque',

            ),



            const SizedBox(height: 12),



            _textField(

              _modele,

              label: 'Modèle',

            ),



            const SizedBox(height: 12),



            _textField(

              _numeroSerie,

              label: 'Numéro de série',

            ),



            const SizedBox(height: 20),



            // ---------------------------------------------------------------

            // ÉTAT / STATUT

            // ---------------------------------------------------------------



            const Text(

              'État et statut',

              style: TextStyle(

                fontSize: 19,

                fontWeight: FontWeight.bold,

              ),

            ),



            const SizedBox(height: 15),



            _etatField(),



            const SizedBox(height: 12),



            _statutField(),



            const SizedBox(height: 20),



            // // ---------------------------------------------------------------

            // // ACHAT / VALEUR

            // // ---------------------------------------------------------------



            // const Text(

            //   'Achat et valeur',

            //   style: TextStyle(

            //     fontSize: 19,

            //     fontWeight: FontWeight.bold,

            //   ),

            // ),



            // const SizedBox(height: 15),



            // TextFormField(

            //   controller: _dateAchat,

            //   readOnly: true,

            //   onTap: _selectDateAchat,

            //   decoration: const InputDecoration(

            //     labelText: 'Date d’achat',

            //     border: OutlineInputBorder(),

            //     suffixIcon: Icon(

            //       Icons.calendar_today,

            //     ),

            //   ),

            // ),



            // const SizedBox(height: 12),



            // _textField(

            //   _valeur,

            //   label: 'Valeur',

            //   keyboardType:

            //       const TextInputType.numberWithOptions(

            //     decimal: true,

            //   ),

            // ),



            // const SizedBox(height: 12),



            // _textField(

            //   _valeurRemplacement,

            //   label: 'Valeur de remplacement',

            //   keyboardType:

            //       const TextInputType.numberWithOptions(

            //     decimal: true,

            //   ),

            // ),



            // const SizedBox(height: 20),



            // // ---------------------------------------------------------------

            // // TIERS / FOURNISSEUR

            // // ---------------------------------------------------------------



            // const Text(

            //   'Location / fournisseur',

            //   style: TextStyle(

            //     fontSize: 19,

            //     fontWeight: FontWeight.bold,

            //   ),

            // ),



            // const SizedBox(height: 10),



            // SwitchListTile(

            //   contentPadding: EdgeInsets.zero,

            //   title: const Text(

            //     'Loué à un tiers',

            //   ),

            //   value: _loueATiers,

            //   onChanged: (value) {

            //     setState(() {

            //       _loueATiers = value;

            //     });

            //   },

            // ),



            // const SizedBox(height: 5),



            // _textField(

            //   _fournisseur,

            //   label: 'Fournisseur',

            // ),



            // const SizedBox(height: 20),



            // // ---------------------------------------------------------------

            // // ASSURANCE

            // // ---------------------------------------------------------------



            // const Text(

            //   'Assurance',

            //   style: TextStyle(

            //     fontSize: 19,

            //     fontWeight: FontWeight.bold,

            //   ),

            // ),



            // const SizedBox(height: 10),



            // SwitchListTile(

            //   contentPadding: EdgeInsets.zero,

            //   title: const Text(

            //     'Assuré',

            //   ),

            //   value: _assure,

            //   onChanged: (value) {

            //     setState(() {

            //       _assure = value;

            //     });

            //   },

            // ),



            // const SizedBox(height: 5),



            // _textField(

            //   _assuranceRef,

            //   label: 'Référence assurance',

            // ),



            // const SizedBox(height: 20),



            // // ---------------------------------------------------------------

            // // BATTERIE / CYCLES

            // // ---------------------------------------------------------------



            // const Text(

            //   'Cycles / batterie',

            //   style: TextStyle(

            //     fontSize: 19,

            //     fontWeight: FontWeight.bold,

            //   ),

            // ),



            // const SizedBox(height: 15),



            // _textField(

            //   _cycles,

            //   label: 'Cycles',

            //   keyboardType:

            //       TextInputType.number,

            // ),



            // const SizedBox(height: 12),



            // _textField(

            //   _cyclesMax,

            //   label: 'Cycles maximum',

            //   keyboardType:

            //       TextInputType.number,

            // ),



            // const SizedBox(height: 30),



            // ---------------------------------------------------------------

            // QR INFO

            // ---------------------------------------------------------------



            Container(

              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(

                border: Border.all(),

                borderRadius:

                    BorderRadius.circular(10),

              ),

              child: const Row(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  Icon(

                    Icons.qr_code_2,

                  ),

                  SizedBox(width: 12),

                  Expanded(

                    child: Text(

                      'Le QR code n’est pas demandé ici. '

                      'Il sera généré automatiquement par le serveur '

                      'lors de l’enregistrement du matériel.',

                    ),

                  ),

                ],

              ),

            ),



            const SizedBox(height: 25),



            // ---------------------------------------------------------------

            // BOUTON ENREGISTRER

            // ---------------------------------------------------------------



            SizedBox(

              height: 52,

              child: FilledButton.icon(

                onPressed: _loading

                    ? null

                    : _create,

                icon: _loading

                    ? const SizedBox(

                        width: 20,

                        height: 20,

                        child:

                            CircularProgressIndicator(

                          strokeWidth: 2,

                        ),

                      )

                    : const Icon(

                        Icons.save,

                      ),

                label: Text(

                  _loading

                      ? 'Enregistrement...'

                      : 'Enregistrer le matériel',

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