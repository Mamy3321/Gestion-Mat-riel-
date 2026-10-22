import 'package:flutter/material.dart';
import '../api.dart';

class EquipmentDetailScreen extends StatefulWidget {
  final int id;

  const EquipmentDetailScreen({
    super.key,
    required this.id,
  });

  @override
  State<EquipmentDetailScreen> createState() =>
      _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final response = await Api.get('/materiels/${widget.id}/');

    if (response is Map<String, dynamic>) {
      return response;
    }

    throw Exception('Réponse invalide du serveur');
  }

  String _value(dynamic value) {
    if (value == null) return '-';

    final text = value.toString().trim();

    if (text.isEmpty || text == 'null') {
      return '-';
    }

    return text;
  }

  Widget _infoRow(
    IconData icon,
    String label,
    dynamic value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Icon(
              icon,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _value(value),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l’équipement'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Impossible de charger les informations.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _future = _fetch();
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final m = snapshot.data!;

          final String nom = _value(m['nom']);

          final String categorie = _value(
            m['categorie_nom'] ??
                m['categorie']?['nom'],
          );

          final String marque = _value(m['marque']);
          final String modele = _value(m['modele']);
          final String numeroSerie = _value(m['numero_serie']);
          final String qrCode = _value(m['qr_code']);

          final dynamic parent = m['kit_parent'];

          String parentNom = '-';

          if (m['kit_parent_nom'] != null) {
            parentNom = _value(m['kit_parent_nom']);
          } else if (parent is Map) {
            parentNom = _value(parent['nom']);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _fetch();
              });

              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 34,
                          child: Icon(
                            Icons.extension_outlined,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          nom,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Équipement',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _infoRow(
                          Icons.category_outlined,
                          'Catégorie',
                          categorie,
                        ),

                        _infoRow(
                          Icons.business_outlined,
                          'Marque',
                          marque,
                        ),

                        _infoRow(
                          Icons.devices_other_outlined,
                          'Modèle',
                          modele,
                        ),

                        _infoRow(
                          Icons.confirmation_number_outlined,
                          'Numéro de série',
                          numeroSerie,
                        ),

                        _infoRow(
                          Icons.qr_code_2,
                          'QR Code',
                          qrCode,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Matériel parent',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(
                              Icons.inventory_2_outlined,
                            ),
                          ),
                          title: const Text(
                            'Matériel principal',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              parentNom,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cet équipement est associé à un matériel principal. '
                          'Son statut opérationnel est géré au niveau du matériel parent.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}