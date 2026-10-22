from rest_framework import serializers

from inventory.models import Materiel

from .models import (
    Emprunt,
    Notification,
    Projet,
    Reservation,
)

from .services import (
    find_conflicts,
    find_emprunt_conflicts,
)


# ============================================================
# RESERVATIONS
# ============================================================

class ReservationSerializer(serializers.ModelSerializer):

    materiel_nom = serializers.CharField(
        source="materiel.nom",
        read_only=True,
    )

    materiel_qr = serializers.CharField(
        source="materiel.qr_code",
        read_only=True,
    )

    projet_nom = serializers.CharField(
        source="projet.nom",
        read_only=True,
    )

    utilisateur_nom = serializers.CharField(
        source="utilisateur.__str__",
        read_only=True,
    )

    class Meta:
        model = Reservation
        fields = "__all__"

        read_only_fields = [
            "utilisateur",
            "statut",
            "date_sortie_reelle",
            "date_retour_reelle",
        ]

    def validate(self, data):

        instance = self.instance

        materiel = data.get(
            "materiel",
            instance.materiel
            if instance
            else None,
        )

        projet = data.get(
            "projet",
            instance.projet
            if instance
            else None,
        )

        debut = data.get(
            "date_sortie_prevue",
            instance.date_sortie_prevue
            if instance
            else None,
        )

        fin = data.get(
            "date_retour_prevue",
            instance.date_retour_prevue
            if instance
            else None,
        )

        if not materiel:
            raise serializers.ValidationError({
                "materiel":
                    "Le matériel est obligatoire."
            })

        if not projet:
            raise serializers.ValidationError({
                "projet":
                    "Le projet est obligatoire."
            })

        if not debut or not fin:
            raise serializers.ValidationError(
                "Les dates de réservation sont obligatoires."
            )

        if fin <= debut:
            raise serializers.ValidationError({
                "date_retour_prevue":
                    "La date de retour doit être après la date de sortie."
            })

        if materiel.statut == (
            Materiel.Statut.HORS_SERVICE
        ):
            raise serializers.ValidationError(
                "Ce matériel est hors service."
            )

        if materiel.statut == (
            Materiel.Statut.MAINTENANCE
        ):
            raise serializers.ValidationError(
                "Ce matériel est actuellement en maintenance."
            )

        conflit = (
            find_conflicts(
                materiel,
                debut,
                fin,
                instance.pk
                if instance
                else None,
            )
            .exclude(
                projet=projet
            )
            .select_related(
                "projet"
            )
            .first()
        )

        if conflit:
            raise serializers.ValidationError(
                f"Conflit : {materiel.nom} est déjà réservé "
                f"pour « {conflit.projet.nom} » sur cette période."
            )

        conflit_emprunt = (
            find_emprunt_conflicts(
                materiel,
                debut,
                fin,
            )
            .select_related(
                "utilisateur"
            )
            .first()
        )

        if conflit_emprunt:
            raise serializers.ValidationError(
                f"Conflit : {materiel.nom} est déjà emprunté "
                "sur cette période."
            )

        return data


# ============================================================
# PROJETS
# ============================================================

class ProjetSerializer(serializers.ModelSerializer):

    responsable_nom = serializers.CharField(
        source="responsable.__str__",
        read_only=True,
    )

    reservations = ReservationSerializer(
        many=True,
        read_only=True,
    )

    nb_materiels = serializers.IntegerField(
        source="reservations.count",
        read_only=True,
    )

    class Meta:
        model = Projet
        fields = "__all__"

        read_only_fields = [
            "responsable",
        ]

    def validate(self, data):

        debut = data.get(
            "date_debut",
            self.instance.date_debut
            if self.instance
            else None,
        )

        fin = data.get(
            "date_fin",
            self.instance.date_fin
            if self.instance
            else None,
        )

        if (
            debut
            and fin
            and fin <= debut
        ):
            raise serializers.ValidationError({
                "date_fin":
                    "La date de fin doit être après la date de début."
            })

        return data


# ============================================================
# EMPRUNTS
# ============================================================

class EmpruntSerializer(serializers.ModelSerializer):

    materiel_nom = serializers.CharField(
        source="materiel.nom",
        read_only=True,
    )

    materiel_qr = serializers.CharField(
        source="materiel.qr_code",
        read_only=True,
    )

    utilisateur_nom = serializers.CharField(
        source="utilisateur.__str__",
        read_only=True,
    )

    created_by_nom = serializers.CharField(
        source="created_by.__str__",
        read_only=True,
    )

    class Meta:
        model = Emprunt
        fields = "__all__"

        read_only_fields = [
            "statut",
            "date_depart_reelle",
            "date_retour_reelle",
            "created_by",
            "created",
        ]

    def validate(self, data):

        instance = self.instance

        materiel = data.get(
            "materiel",
            instance.materiel
            if instance
            else None,
        )

        utilisateur = data.get(
            "utilisateur",
            instance.utilisateur
            if instance
            else None,
        )

        debut = data.get(
            "date_depart_prevue",
            instance.date_depart_prevue
            if instance
            else None,
        )

        fin = data.get(
            "date_retour_prevue",
            instance.date_retour_prevue
            if instance
            else None,
        )

        if not materiel:
            raise serializers.ValidationError({
                "materiel":
                    "Le matériel est obligatoire."
            })

        if not utilisateur:
            raise serializers.ValidationError({
                "utilisateur":
                    "L'emprunteur est obligatoire."
            })

        if not debut or not fin:
            raise serializers.ValidationError(
                "Les dates de l'emprunt sont obligatoires."
            )

        if fin <= debut:
            raise serializers.ValidationError({
                "date_retour_prevue":
                    "La date de retour doit être après la date de départ."
            })

        if materiel.statut == (
            Materiel.Statut.HORS_SERVICE
        ):
            raise serializers.ValidationError(
                "Ce matériel est hors service."
            )

        if materiel.statut == (
            Materiel.Statut.MAINTENANCE
        ):
            raise serializers.ValidationError(
                "Ce matériel est actuellement en maintenance."
            )

        conflit = (
            find_conflicts(
                materiel,
                debut,
                fin,
            )
            .select_related(
                "projet"
            )
            .first()
        )

        if conflit:
            raise serializers.ValidationError(
                f"Conflit : {materiel.nom} est réservé "
                f"pour « {conflit.projet.nom} » sur cette période."
            )

        conflit_emprunt = (
            find_emprunt_conflicts(
                materiel,
                debut,
                fin,
                instance.pk
                if instance
                else None,
            )
            .select_related(
                "utilisateur"
            )
            .first()
        )

        if conflit_emprunt:
            raise serializers.ValidationError(
                f"Conflit : {materiel.nom} est déjà emprunté "
                "sur cette période."
            )

        return data


# ============================================================
# NOTIFICATIONS
# ============================================================

class NotificationSerializer(serializers.ModelSerializer):
    utilisateur_nom = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = [
            "id",
            "utilisateur",
            "utilisateur_nom",
            "titre",
            "message",
            "lu",
            "created",
        ]
        read_only_fields = [
            "id",
            "utilisateur_nom",
            "lu",
            "created",
        ]

    def get_utilisateur_nom(self, obj):
        if not obj.utilisateur:
            return ""

        return (
            obj.utilisateur.get_full_name()
            or obj.utilisateur.username
            or obj.utilisateur.email
        )


class NotificationCreateSerializer(
    serializers.ModelSerializer
):
    """
    Serializer utilisé par l'administrateur
    pour envoyer une notification.

    Il accepte :

    1. Un seul destinataire :

    {
        "utilisateur": 5,
        "titre": "Urgent",
        "message": "Réunion à 14h."
    }

    2. Plusieurs destinataires :

    {
        "utilisateur_ids": [5, 8, 12],
        "titre": "Urgent",
        "message": "Réunion à 14h."
    }

    Le ViewSet crée ensuite une notification
    privée pour chaque destinataire.
    """

    utilisateur_ids = serializers.ListField(
        child=serializers.IntegerField(),
        required=False,
        write_only=True,
    )

    class Meta:
        model = Notification

        fields = [
            "id",
            "utilisateur",
            "utilisateur_ids",
            "titre",
            "message",
            "lu",
            "created",
        ]

        read_only_fields = [
            "id",
            "lu",
            "created",
        ]

        extra_kwargs = {
            "utilisateur": {
                "required": False,
                "allow_null": True,
            },
        }

    def validate_titre(
        self,
        value,
    ):

        value = value.strip()

        if not value:

            raise serializers.ValidationError(
                "Le titre est obligatoire."
            )

        return value

    def validate_message(
        self,
        value,
    ):

        value = value.strip()

        if not value:

            raise serializers.ValidationError(
                "Le message est obligatoire."
            )

        return value

    def validate(
        self,
        attrs,
    ):

        utilisateur = attrs.get(
            "utilisateur"
        )

        utilisateur_ids = attrs.get(
            "utilisateur_ids"
        )

        if not utilisateur and not utilisateur_ids:

            raise serializers.ValidationError({
                "destinataire":
                    "Sélectionnez au moins un destinataire."
            })

        if utilisateur and utilisateur_ids:

            raise serializers.ValidationError({
                "destinataire":
                    "Utilisez soit utilisateur, "
                    "soit utilisateur_ids."
            })

        if utilisateur_ids:

            if len(utilisateur_ids) == 0:

                raise serializers.ValidationError({
                    "utilisateur_ids":
                        "La liste des destinataires "
                        "ne peut pas être vide."
                })

            # Suppression des doublons
            attrs["utilisateur_ids"] = list(
                dict.fromkeys(
                    utilisateur_ids
                )
            )

        return attrs