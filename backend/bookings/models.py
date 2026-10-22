from django.conf import settings
from django.db import models

from inventory.models import Materiel


class Projet(models.Model):
    class Statut(models.TextChoices):
        PREPARATION = "preparation", "En préparation"
        EN_COURS = "en_cours", "En cours"
        TERMINE = "termine", "Terminé"
        ANNULE = "annule", "Annulé"

    nom = models.CharField(max_length=150)

    date_debut = models.DateTimeField()
    date_fin = models.DateTimeField()

    lieu = models.CharField(
        max_length=150,
        blank=True,
    )

    responsable = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="projets_geres",
    )

    equipe = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name="projets",
    )

    statut = models.CharField(
        max_length=15,
        choices=Statut.choices,
        default=Statut.PREPARATION,
    )

    class Meta:
        ordering = ["-date_debut"]

    def __str__(self):
        return self.nom


class Reservation(models.Model):
    class Statut(models.TextChoices):
        RESERVEE = "reservee", "Réservée"
        SORTIE = "sortie", "Sortie"
        RETOURNEE = "retournee", "Retournée"
        ANNULEE = "annulee", "Annulée"

    materiel = models.ForeignKey(
        Materiel,
        on_delete=models.CASCADE,
        related_name="reservations",
    )

    projet = models.ForeignKey(
        Projet,
        on_delete=models.CASCADE,
        related_name="reservations",
    )

    utilisateur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="reservations",
    )

    date_sortie_prevue = models.DateTimeField()
    date_retour_prevue = models.DateTimeField()

    date_sortie_reelle = models.DateTimeField(
        null=True,
        blank=True,
    )

    date_retour_reelle = models.DateTimeField(
        null=True,
        blank=True,
    )

    statut = models.CharField(
        max_length=10,
        choices=Statut.choices,
        default=Statut.RESERVEE,
    )

    notes = models.TextField(blank=True)

    class Meta:
        ordering = ["-date_sortie_prevue"]

    def __str__(self):
        return f"{self.materiel} → {self.projet}"


class Emprunt(models.Model):
    class Statut(models.TextChoices):
        PLANIFIE = "planifie", "Planifié"
        EN_COURS = "en_cours", "En cours"
        EN_RETARD = "en_retard", "En retard"
        RETOURNE = "retourne", "Retourné"
        ANNULE = "annule", "Annulé"

    materiel = models.ForeignKey(
        Materiel,
        on_delete=models.PROTECT,
        related_name="emprunts",
    )

    utilisateur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="emprunts",
    )

    motif = models.CharField(
        max_length=200,
        blank=True,
    )

    date_depart_prevue = models.DateTimeField()
    date_retour_prevue = models.DateTimeField()

    date_depart_reelle = models.DateTimeField(
        null=True,
        blank=True,
    )

    date_retour_reelle = models.DateTimeField(
        null=True,
        blank=True,
    )

    # Montant de l'emprunt en Ariary - facultatif
    montant = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True,
    )

    statut = models.CharField(
        max_length=10,
        choices=Statut.choices,
        default=Statut.PLANIFIE,
    )

    notes = models.TextField(blank=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="emprunts_crees",
        null=True,
        blank=True,
    )

    created = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = ["-date_depart_prevue"]

    def __str__(self):
        return f"{self.materiel} → {self.utilisateur}"


class Notification(models.Model):
    utilisateur = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )

    titre = models.CharField(
        max_length=150,
    )

    message = models.TextField(
        blank=True,
    )

    lu = models.BooleanField(
        default=False,
    )

    cle = models.CharField(
        max_length=120,
        blank=True,
        db_index=True,
    )

    created = models.DateTimeField(
        auto_now_add=True,
    )

    class Meta:
        ordering = ["-created"]