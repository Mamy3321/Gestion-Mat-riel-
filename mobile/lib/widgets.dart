import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api.dart';

const statutLabels = {
  'dispo': 'Disponible',
  'tournage': 'En tournage',
  'maintenance': 'En maintenance',
  'hors_service': 'Hors service',
  'emprunte': 'Emprunté',
};

Color statutColor(String s) {
  switch (s) {
    case 'dispo':
      return Colors.green;

    case 'tournage':
      return Colors.blue;

    case 'maintenance':
      return Colors.orange;

    case 'emprunte':
      return Colors.purple;

    case 'hors_service':
      return Colors.red;

    default:
      return Colors.grey;
  }
}

String fmt(String? iso, {bool time = true}) {
  if (iso == null) return '-';

  return DateFormat(
    time ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy',
  ).format(
    DateTime.parse(iso).toLocal(),
  );
}

String isoUtc(DateTime d) =>
    d.toUtc().toIso8601String();

void toast(
  BuildContext c,
  String m,
) =>
    ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(
        content: Text(m),
        duration: const Duration(seconds: 4),
      ),
    );

Future<T?> guard<T>(
  BuildContext c,
  Future<T> Function() f,
) async {
  try {
    return await f();
  } on ApiException catch (e) {
    if (c.mounted) {
      toast(c, e.message);
    }
  } catch (_) {
    if (c.mounted) {
      toast(c, 'Réseau indisponible.');
    }
  }

  return null;
}

class StatutChip extends StatelessWidget {
  final String statut;
  final String? label;

  const StatutChip(
    this.statut, {
    super.key,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = statutColor(statut);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label ??
            statutLabels[statut] ??
            statut,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Statut d'un emprunt.
String empruntStatutLabel(String statut) {
  switch (statut) {
    case 'planifie':
      return 'Planifié';

    case 'en_cours':
      return 'En cours';

    case 'en_retard':
      return 'En retard';

    case 'retourne':
      return 'Retourné';

    case 'annule':
      return 'Annulé';

    default:
      return statut;
  }
}

Color empruntStatutColor(String statut) {
  switch (statut) {
    case 'planifie':
      return Colors.blue;

    case 'en_cours':
      return Colors.orange;

    case 'en_retard':
      return Colors.red;

    case 'retourne':
      return Colors.green;

    case 'annule':
      return Colors.grey;

    default:
      return Colors.grey;
  }
}

class EmpruntStatutChip extends StatelessWidget {
  final String statut;

  const EmpruntStatutChip(
    this.statut, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final c = empruntStatutColor(statut);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        empruntStatutLabel(statut),
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class Loader extends StatelessWidget {
  final Future<dynamic> future;
  final Widget Function(dynamic data) builder;
  final Future<void> Function() onRefresh;

  const Loader({
    super.key,
    required this.future,
    required this.builder,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) =>
      FutureBuilder(
        future: future,
        builder: (c, s) {
          if (s.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (s.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      '${s.error}',
                      textAlign:
                          TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: onRefresh,
                      child:
                          const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: onRefresh,
            child: builder(s.data),
          );
        },
      );
}