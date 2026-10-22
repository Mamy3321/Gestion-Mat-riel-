import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late Future<dynamic> _f = Api.get('/maintenances/');
  Future<void> _reload() async {
    setState(() => _f = Api.get('/maintenances/'));
    await _f.catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Maintenance')),
        body: Loader(
          future: _f,
          onRefresh: _reload,
          builder: (d) {
            final items = List.from(d);
            if (items.isEmpty) return ListView(children: const [SizedBox(height: 80), Center(child: Text('Aucune intervention'))]);
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (c, i) {
                final m = items[i];
                final done = m['statut'] == 'terminee';
                return ListTile(
                  leading: Icon(done ? Icons.check_circle : Icons.build_circle, color: done ? Colors.green : Colors.orange),
                  title: Text(m['materiel_nom']),
                  subtitle: Text('${m['type']} • ${m['date']}\n${m['description']}'),
                  isThreeLine: true,
                  trailing: (!done && Api.canWrite)
                      ? TextButton(
                          child: const Text('Terminer'),
                          onPressed: () async {
                            await guard(context, () => Api.patch('/maintenances/${m['id']}/', {'statut': 'terminee'}));
                            _reload();
                          })
                      : null,
                );
              },
            );
          },
        ),
      );
}
