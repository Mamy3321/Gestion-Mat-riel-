import uuid

from django.db import models
from django.utils import timezone


class Categorie(models.Model):
    nom = models.CharField(max_length=80, unique=True)

    class Meta:
        ordering = ["nom"]

    def __str__(self):
        return self.nom


class Materiel(models.Model):
    class Etat(models.TextChoices):
        NEUF = "neuf", "Neuf"
        BON = "bon", "Bon"
        USE = "use", "Usé"
        HS = "hs", "HS"

    class Statut(models.TextChoices):
        DISPO = "dispo", "Disponible"
        TOURNAGE = "tournage", "En tournage"
        EMPRUNTE = "emprunte", "Emprunté"
        MAINTENANCE = "maintenance", "En maintenance"
        HORS_SERVICE = "hors_service", "Hors service"

    nom = models.CharField(max_length=150)

    categorie = models.ForeignKey(
        Categorie,
        on_delete=models.PROTECT,
        related_name="materiels",
    )

    marque = models.CharField(
        max_length=80,
        blank=True,
    )

    modele = models.CharField(
        max_length=80,
        blank=True,
    )

    numero_serie = models.CharField(
        max_length=80,
        blank=True,
    )

    etat = models.CharField(
        max_length=10,
        choices=Etat.choices,
        default=Etat.BON,
    )

    statut = models.CharField(
        max_length=15,
        choices=Statut.choices,
        default=Statut.DISPO,
    )

    # Photo facultative
    photo = models.ImageField(
        upload_to="materiels/",
        null=True,
        blank=True,
    )

    # QR généré automatiquement
    qr_code = models.CharField(
        max_length=30,
        unique=True,
        blank=True,
        editable=False,
    )

    # Parent du matériel.
    # Exemple :
    # Drone DJI -> parent
    # Batterie -> kit_parent = Drone DJI
    kit_parent = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="accessoires",
    )

    class Meta:
        ordering = ["nom"]

    def save(self, *args, **kwargs):
        if not self.qr_code:
            self.qr_code = (
                "MAT-"
                + uuid.uuid4().hex[:10].upper()
            )

        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.nom} ({self.qr_code})"


class Maintenance(models.Model):
    class Type(models.TextChoices):
        PANNE = "panne", "Panne / casse"
        REVISION = "revision", "Révision"
        NETTOYAGE = "nettoyage", "Nettoyage capteur"
        CALIBRATION = "calibration", "Calibration"

    class Statut(models.TextChoices):
        OUVERTE = "ouverte", "Ouverte"
        EN_COURS = "en_cours", "En cours"
        TERMINEE = "terminee", "Terminée"

    materiel = models.ForeignKey(
        Materiel,
        on_delete=models.CASCADE,
        related_name="maintenances",
    )

    type = models.CharField(
        max_length=15,
        choices=Type.choices,
        default=Type.PANNE,
    )

    description = models.TextField(blank=True)

    date = models.DateField(
        default=timezone.localdate,
    )

    cout = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0,
    )

    statut = models.CharField(
        max_length=10,
        choices=Statut.choices,
        default=Statut.OUVERTE,
    )

    class Meta:
        ordering = ["-date", "-id"]

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

        materiel = self.materiel

        if materiel.statut == Materiel.Statut.HORS_SERVICE:
            return

        if self.statut != self.Statut.TERMINEE:
            materiel.statut = Materiel.Statut.MAINTENANCE

        elif (
            materiel.statut == Materiel.Statut.MAINTENANCE
            and not materiel.maintenances.exclude(
                statut=self.Statut.TERMINEE
            ).exists()
        ):
            materiel.statut = Materiel.Statut.DISPO

        materiel.save(update_fields=["statut"])