"""Rappels de retour, alertes de retard et maintenance préventive.
À planifier (cron / Planificateur de tâches Windows), ex. toutes les heures :
    python manage.py send_reminders
"""
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from bookings.models import Notification, Reservation
from inventory.models import Materiel


def notifier(user, titre, message, cle):
    _, created = Notification.objects.get_or_create(
        utilisateur=user, cle=cle, defaults={"titre": titre, "message": message})
    return created


class Command(BaseCommand):
    help = "Génère les notifications de rappel / retard / maintenance préventive"

    def handle(self, *args, **opts):
        now, n = timezone.now(), 0
        admins = list(User.objects.filter(role="admin"))
        sorties = Reservation.objects.filter(statut="sortie").select_related("materiel", "projet", "utilisateur")
        for r in sorties:
            if r.date_retour_prevue < now:
                for u in {r.utilisateur, *admins}:
                    n += notifier(u, "Retard de retour", f"{r.materiel.nom} ({r.projet.nom}) aurait dû être rendu.",
                                  f"retard-{r.pk}-{u.pk}")
            elif r.date_retour_prevue < now + timedelta(hours=24):
                n += notifier(r.utilisateur, "Retour à prévoir",
                              f"{r.materiel.nom} doit être rendu bientôt ({r.projet.nom}).", f"rappel-{r.pk}")
        for m in Materiel.objects.filter(cycles_max__isnull=False):
            if m.cycles_max and m.cycles >= 0.9 * m.cycles_max:
                for u in admins:
                    n += notifier(u, "Maintenance préventive", f"{m.nom} : {m.cycles}/{m.cycles_max} cycles.",
                                  f"cycles-{m.pk}-{m.cycles_max}-{u.pk}")
        self.stdout.write(f"{n} notification(s) créée(s).")
