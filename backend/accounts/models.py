from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):

    class Role(models.TextChoices):
        ADMIN = "admin", "Admin"
        EQUIPE = "equipe", "Équipe"
        UTILISATEUR = "utilisateur", "Utilisateur simple"

    class ValidationStatus(models.TextChoices):
        PENDING = "pending", "En attente"
        APPROVED = "approved", "Validé"
        REJECTED = "rejected", "Refusé"

    role = models.CharField(
        max_length=20,
        choices=Role.choices,
        default=Role.UTILISATEUR,
    )

    validation_status = models.CharField(
        max_length=20,
        choices=ValidationStatus.choices,
        default=ValidationStatus.PENDING,
    )

    photo = models.ImageField(
        upload_to="profiles/",
        null=True,
        blank=True,
    )

    def __str__(self):
        return self.get_full_name() or self.username