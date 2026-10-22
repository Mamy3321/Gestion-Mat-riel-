from datetime import date, timedelta

from django.core.management.base import BaseCommand

from accounts.models import User
from inventory.models import Categorie, Materiel


class Command(BaseCommand):
    help = "Crée des utilisateurs et du matériel de démonstration"

    def handle(self, *args, **opts):
        for username, role, pwd in [("admin", "admin", "admin123"), ("tech", "technicien", "tech123"),
                                    ("real", "realisateur", "real123")]:
            u, created = User.objects.get_or_create(username=username, defaults={
                "role": role, "email": f"{username}@example.com", "is_staff": role == "admin",
                "is_superuser": role == "admin"})
            if created:
                u.set_password(pwd)
                u.save()
        cats = {n: Categorie.objects.get_or_create(nom=n)[0] for n in
                ["Caméra", "Objectif", "Lumière", "Son", "Support", "Batterie", "Accessoire", "Stockage"]}
        if Materiel.objects.exists():
            return self.stdout.write("Matériel déjà présent.")
        cam = Materiel.objects.create(nom="Sony FX6", categorie=cats["Caméra"], marque="Sony", modele="FX6",
                                      numero_serie="SN-FX6-001", valeur=6500, valeur_remplacement=7200,
                                      date_achat=date.today() - timedelta(days=700), assure=True)
        for nom, cat, extra in [("Batterie BP-U100 #1", "Batterie", {"cycles": 285, "cycles_max": 300}),
                                ("Carte CFexpress 512Go", "Stockage", {})]:
            Materiel.objects.create(nom=nom, categorie=cats[cat], kit_parent=cam, valeur=250, **extra)
        Materiel.objects.create(nom="Sigma 24-70 f/2.8", categorie=cats["Objectif"], marque="Sigma", valeur=1100)
        Materiel.objects.create(nom="Aputure 300d II", categorie=cats["Lumière"], marque="Aputure", valeur=900,
                                loue_a_tiers=True, fournisseur="LumiLoc")
        Materiel.objects.create(nom="Micro Rode NTG5", categorie=cats["Son"], marque="Rode", valeur=500)
        Materiel.objects.create(nom="Trépied Sachtler", categorie=cats["Support"], marque="Sachtler", valeur=1800,
                                date_achat=date.today() - timedelta(days=365 * 6))
        self.stdout.write("Données de démo créées. Comptes : admin/admin123, tech/tech123, real/real123")
