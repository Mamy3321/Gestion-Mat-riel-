from io import BytesIO

from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import get_object_or_404

import qrcode

from django_filters.rest_framework import DjangoFilterBackend

from rest_framework import filters, status, viewsets
from rest_framework.decorators import action
from rest_framework.parsers import (
    JSONParser,
    MultiPartParser,
    FormParser,
)
from rest_framework.response import Response

from accounts.permissions import RolePermission

# ============================================================
# SYNCHRONISATION PROJETS / MATERIELS
# ============================================================

from bookings.services import update_material_status

from .models import (
    Categorie,
    Maintenance,
    Materiel,
)

from .serializers import (
    CategorieSerializer,
    MaintenanceSerializer,
    MaterielSerializer,
    MaterielCreateSerializer,
)


# ============================================================
# CATEGORIES
# ============================================================

class CategorieViewSet(viewsets.ModelViewSet):

    queryset = Categorie.objects.all()

    serializer_class = CategorieSerializer

    permission_classes = [
        RolePermission,
    ]

    write_roles = (
        "admin",
    )

    pagination_class = None


# ============================================================
# MATERIELS
# ============================================================

class MaterielViewSet(viewsets.ModelViewSet):

    queryset = (
        Materiel.objects
        .select_related(
            "categorie",
            "kit_parent",
        )
        .prefetch_related(
            "accessoires",
        )
    )

    serializer_class = MaterielSerializer

    permission_classes = [
        RolePermission,
    ]

    write_roles = (
        "admin",
    )

    pagination_class = None

    parser_classes = [
        JSONParser,
        MultiPartParser,
        FormParser,
    ]

    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
    ]

    filterset_fields = [
        "categorie",
        "statut",
        "etat",
        "kit_parent",
    ]

    search_fields = [
        "nom",
        "marque",
        "modele",
        "numero_serie",
        "qr_code",
    ]

    # ========================================================
    # LIST
    # ========================================================

    def list(
        self,
        request,
        *args,
        **kwargs,
    ):
        """
        Synchronise automatiquement les projets et les
        matériels avant de retourner l'inventaire.

        Exemple :

            Projet :
                16/10/2026 -> 17/10/2026

            Aujourd'hui :
                16/10/2026

            Projet :
                preparation -> en_cours

            Matériel réservé pour ce projet :
                dispo -> tournage
        """

        update_material_status()

        return super().list(
            request,
            *args,
            **kwargs,
        )

    # ========================================================
    # QUERYSET
    # ========================================================

    def get_queryset(self):
        """
        Retourne les matériels.

        Par défaut :
            - tous les matériels sont accessibles à l'API.

        Avec :
            ?root=true

        on retourne uniquement les matériels parents,
        c'est-à-dire ceux qui n'ont pas de kit_parent.

        Exemple :

            Sony FX6
                kit_parent = NULL
                => affiché

            Batterie BP-U100
                kit_parent = Sony FX6
                => non affichée

            Carte CFexpress
                kit_parent = Sony FX6
                => non affichée
        """

        queryset = (
            Materiel.objects
            .select_related(
                "categorie",
                "kit_parent",
            )
            .prefetch_related(
                "accessoires",
            )
        )

        # ----------------------------------------------------
        # INVENTAIRE PRINCIPAL
        # ----------------------------------------------------

        if self.request.query_params.get(
            "root"
        ) == "true":

            queryset = queryset.filter(
                kit_parent__isnull=True
            )

        return queryset

    # ========================================================
    # CREATE
    # ========================================================

    def create(
        self,
        request,
        *args,
        **kwargs,
    ):
        """
        Création normale d'un matériel parent.

        Un équipement enfant ne doit pas être créé
        directement avec le CRUD général.

        Pour créer un matériel avec ses équipements,
        utiliser :

            POST /api/materiels/avec-equipements/
        """

        # ----------------------------------------------------
        # INTERDIRE LA CREATION DIRECTE D'UN ENFANT
        # ----------------------------------------------------

        if request.data.get(
            "kit_parent"
        ):

            return Response(
                {
                    "detail": (
                        "Un équipement associé doit être "
                        "créé depuis son matériel parent."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = MaterielCreateSerializer(
            data=request.data,
            context={
                "request": request,
            },
        )

        serializer.is_valid(
            raise_exception=True
        )

        # ----------------------------------------------------
        # CREATION TRANSACTIONNELLE
        # ----------------------------------------------------

        with transaction.atomic():

            materiel = serializer.save()

        # ----------------------------------------------------
        # REPONSE COMPLETE
        # ----------------------------------------------------

        output = MaterielSerializer(
            materiel,
            context={
                "request": request,
            },
        )

        return Response(
            output.data,
            status=status.HTTP_201_CREATED,
        )

    # ========================================================
    # CREATE AVEC EQUIPEMENTS
    # ========================================================

    @transaction.atomic
    @action(
        detail=False,
        methods=["post"],
        url_path="avec-equipements",
    )
    def avec_equipements(
        self,
        request,
    ):
        """
        Crée un matériel principal et ses équipements
        dans la même transaction.

        Exemple :

            Drone
                ├── Batterie
                ├── Radiocommande
                └── Hélices

        Les équipements restent liés au parent.

        Le matériel parent est le seul élément destiné
        à être utilisé dans l'inventaire principal.
        """

        serializer = MaterielCreateSerializer(
            data=request.data,
            context={
                "request": request,
            },
        )

        serializer.is_valid(
            raise_exception=True
        )

        materiel = serializer.save()

        output = MaterielSerializer(
            materiel,
            context={
                "request": request,
            },
        )

        return Response(
            output.data,
            status=status.HTTP_201_CREATED,
        )

    # ========================================================
    # UPDATE
    # ========================================================

    def update(
        self,
        request,
        *args,
        **kwargs,
    ):
        """
        Modification d'un matériel parent.

        Un équipement enfant ne peut pas être modifié
        comme matériel indépendant.

        IMPORTANT :
        Le statut du parent n'est PAS propagé aux enfants.

        Exemple :

            Sony FX6
                statut = tournage

            Batterie
                aucun statut métier indépendant

            Carte CFexpress
                aucun statut métier indépendant
        """

        instance = self.get_object()

        # ----------------------------------------------------
        # INTERDIRE MODIFICATION DIRECTE D'UN ENFANT
        # ----------------------------------------------------

        if instance.kit_parent_id:

            return Response(
                {
                    "detail": (
                        "Cet équipement appartient à "
                        "un matériel parent. Modifiez-le "
                        "depuis le matériel parent."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ----------------------------------------------------
        # UPDATE DU PARENT
        # ----------------------------------------------------

        response = super().update(
            request,
            *args,
            **kwargs,
        )

        instance.refresh_from_db()

        # ----------------------------------------------------
        # AUCUNE PROPAGATION DU STATUT AUX ENFANTS
        # ----------------------------------------------------

        serializer = MaterielSerializer(
            instance,
            context={
                "request": request,
            },
        )

        return Response(
            serializer.data,
            status=response.status_code,
        )

    # ========================================================
    # PARTIAL UPDATE
    # ========================================================

    def partial_update(
        self,
        request,
        *args,
        **kwargs,
    ):
        """
        PATCH d'un matériel parent.

        Un enfant ne peut pas être modifié directement.
        """

        instance = self.get_object()

        if instance.kit_parent_id:

            return Response(
                {
                    "detail": (
                        "Cet équipement appartient à "
                        "un matériel parent. Modifiez-le "
                        "depuis le matériel parent."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        response = super().partial_update(
            request,
            *args,
            **kwargs,
        )

        instance.refresh_from_db()

        serializer = MaterielSerializer(
            instance,
            context={
                "request": request,
            },
        )

        return Response(
            serializer.data,
            status=response.status_code,
        )

    # ========================================================
    # DELETE
    # ========================================================

    def destroy(
        self,
        request,
        *args,
        **kwargs,
    ):
        """
        Suppression d'un matériel parent.

        Un équipement enfant ne peut jamais être supprimé
        directement.

        Un parent qui possède encore des équipements ne peut
        pas non plus être supprimé directement.
        """

        instance = self.get_object()

        # ----------------------------------------------------
        # INTERDIRE SUPPRESSION DIRECTE D'UN ENFANT
        # ----------------------------------------------------

        if instance.kit_parent_id:

            return Response(
                {
                    "detail": (
                        "Cet équipement appartient à "
                        "un matériel parent. Supprimez-le "
                        "depuis le matériel parent."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ----------------------------------------------------
        # INTERDIRE SUPPRESSION DU PARENT AVEC ENFANTS
        # ----------------------------------------------------

        if instance.accessoires.exists():

            return Response(
                {
                    "detail": (
                        "Ce matériel possède des "
                        "équipements associés. "
                        "Supprimez d'abord ses équipements "
                        "depuis sa fiche."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        return super().destroy(
            request,
            *args,
            **kwargs,
        )

    # ========================================================
    # RECHERCHE PAR QR
    # ========================================================

    @action(
        detail=False,
        methods=["get"],
        url_path="par-qr",
    )
    def par_qr(
        self,
        request,
    ):
        """
        Recherche d'un matériel à partir de son QR Code.

        Le QR appartient au matériel.
        """

        code = request.query_params.get(
            "code",
            "",
        ).strip()

        if not code:

            return Response(
                {
                    "detail": "QR Code obligatoire."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        obj = get_object_or_404(
            self.get_queryset(),
            qr_code=code,
        )

        return Response(
            self.get_serializer(obj).data
        )

    # ========================================================
    # QR CODE IMAGE
    # ========================================================

    @action(
        detail=True,
        methods=["get"],
    )
    def qr(
        self,
        request,
        pk=None,
    ):
        """
        Génère l'image du QR Code du matériel.
        """

        obj = self.get_object()

        buf = BytesIO()

        qrcode.make(
            obj.qr_code
        ).save(
            buf,
            format="PNG",
        )

        return HttpResponse(
            buf.getvalue(),
            content_type="image/png",
        )

    # ========================================================
    # HISTORIQUE
    # ========================================================

    @action(
        detail=True,
        methods=["get"],
    )
    def historique(
        self,
        request,
        pk=None,
    ):
        """
        Historique du matériel parent :
            - réservations
            - maintenances
        """

        m = self.get_object()

        reservations = [
            {
                "projet": r.projet.nom,

                "utilisateur": str(
                    r.utilisateur
                ),

                "sortie": (
                    r.date_sortie_reelle
                    or r.date_sortie_prevue
                ),

                "retour": (
                    r.date_retour_reelle
                    or r.date_retour_prevue
                ),

                "statut": r.statut,
            }

            for r in (
                m.reservations
                .select_related(
                    "projet",
                    "utilisateur",
                )[:30]
            )
        ]

        return Response(
            {
                "reservations": reservations,

                "maintenances": MaintenanceSerializer(
                    m.maintenances.all()[:30],
                    many=True,
                ).data,
            }
        )


# ============================================================
# MAINTENANCE
# ============================================================

class MaintenanceViewSet(
    viewsets.ModelViewSet
):

    queryset = (
        Maintenance.objects
        .select_related(
            "materiel"
        )
    )

    serializer_class = MaintenanceSerializer

    permission_classes = [
        RolePermission,
    ]

    write_roles = (
        "admin",
        "technicien",
    )

    pagination_class = None

    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
    ]

    filterset_fields = [
        "materiel",
        "statut",
        "type",
    ]

    search_fields = [
        "materiel__nom",
        "materiel__marque",
        "materiel__modele",
        "description",
    ]