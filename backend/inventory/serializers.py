from rest_framework import serializers

from .models import (
    Categorie,
    Maintenance,
    Materiel,
)


# ============================================================
# CATEGORIE
# ============================================================

class CategorieSerializer(serializers.ModelSerializer):

    class Meta:
        model = Categorie
        fields = "__all__"


# ============================================================
# MATERIEL
# ============================================================

class MaterielSerializer(
    serializers.ModelSerializer
):

    categorie_nom = serializers.CharField(
        source="categorie.nom",
        read_only=True,
    )

    kit_parent_nom = serializers.CharField(
        source="kit_parent.nom",
        read_only=True,
        default=None,
    )

    accessoires = serializers.SerializerMethodField()

    class Meta:
        model = Materiel
        fields = "__all__"

        read_only_fields = [
            "qr_code",
        ]

    # ========================================================
    # EQUIPEMENTS DU PARENT
    # ========================================================

    def get_accessoires(self, obj):
        """
        Retourne les équipements associés au matériel parent.

        IMPORTANT :

        Un équipement enfant ne possède pas de statut métier
        indépendant dans l'interface.

        Il ne possède pas non plus de QR Code indépendant.

        Le statut et le QR Code appartiennent au matériel parent.
        """

        return [
            {
                "id": accessoire.id,

                "nom": accessoire.nom,

                "categorie": (
                    accessoire.categorie.nom
                    if accessoire.categorie
                    else ""
                ),

                "marque": (
                    accessoire.marque
                    or ""
                ),

                "modele": (
                    accessoire.modele
                    or ""
                ),

                "numero_serie": (
                    accessoire.numero_serie
                    or ""
                ),

                "etat": (
                    accessoire.etat
                    or ""
                ),
            }

            for accessoire
            in obj.accessoires.all()
        ]


# ============================================================
# CREATION MATERIEL
# ============================================================

class MaterielCreateSerializer(
    serializers.ModelSerializer
):

    class Meta:
        model = Materiel
        fields = "__all__"

        read_only_fields = [
            "id",
            "qr_code",
        ]

    def validate_kit_parent(
        self,
        value,
    ):
        """
        Le CRUD général ne doit pas créer directement
        un équipement enfant.

        La création d'un enfant doit passer par
        le mécanisme du matériel parent.
        """

        if value is not None:
            raise serializers.ValidationError(
                "Un équipement doit être créé "
                "depuis son matériel parent."
            )

        return value


# ============================================================
# MAINTENANCE
# ============================================================

class MaintenanceSerializer(
    serializers.ModelSerializer
):

    materiel_nom = serializers.CharField(
        source="materiel.nom",
        read_only=True,
    )

    class Meta:
        model = Maintenance
        fields = "__all__"