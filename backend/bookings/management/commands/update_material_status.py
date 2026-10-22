from django.core.management.base import BaseCommand

from bookings.services import update_material_status


class Command(BaseCommand):

    help = (
        "Met à jour automatiquement les statuts "
        "des projets, matériels et emprunts."
    )

    def handle(
        self,
        *args,
        **options,
    ):

        result = update_material_status()

        self.stdout.write(
            self.style.SUCCESS(
                "Mise à jour terminée : "
                f"{result['projets_demarre']} projet(s), "
                f"{result['emprunts_en_retard']} emprunt(s) en retard."
            )
        )