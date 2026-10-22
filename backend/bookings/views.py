from datetime import timedelta
from io import BytesIO

from django.db import transaction
from django.db.models import Count
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from django_filters.rest_framework import DjangoFilterBackend

from rest_framework import (
    status,
    viewsets,
    filters,
    serializers,
)

from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from accounts.permissions import RolePermission

from inventory.models import Materiel

from . import services

from .models import (
    Emprunt,
    Notification,
    Projet,
    Reservation,
)

from .serializers import (
    EmpruntSerializer,
    NotificationSerializer,
    NotificationCreateSerializer,
    ProjetSerializer,
    ReservationSerializer,
)

from .services import synchronize_all


# ============================================================
# PROJETS
# ============================================================

class ProjetViewSet(viewsets.ModelViewSet):

    queryset = (
        Projet.objects
        .select_related("responsable")
        .prefetch_related(
            "reservations__materiel",
            "reservations__projet",
            "reservations__utilisateur",
        )
    )

    serializer_class = ProjetSerializer

    permission_classes = [
        RolePermission,
    ]

    write_roles = (
        "admin",
        "technicien",
        "realisateur",
    )

    pagination_class = None

    filter_backends = [
        DjangoFilterBackend,
        filters.SearchFilter,
    ]

    filterset_fields = [
        "statut",
        "responsable",
    ]

    search_fields = [
        "nom",
        "lieu",
    ]

    def perform_create(self, serializer):

        serializer.save(
            responsable=self.request.user
        )

    def perform_update(self, serializer):

        ancien = self.get_object()

        nouveau_debut = serializer.validated_data.get(
            "date_debut",
            ancien.date_debut,
        )

        nouveau_fin = serializer.validated_data.get(
            "date_fin",
            ancien.date_fin,
        )

        if nouveau_fin <= nouveau_debut:

            raise serializers.ValidationError({
                "date_fin":
                    "La date de fin doit être après la date de début."
            })

        dates_changees = (
            nouveau_debut != ancien.date_debut
            or nouveau_fin != ancien.date_fin
        )

        if dates_changees:

            reservations = (
                ancien.reservations
                .filter(
                    statut__in=services.ACTIVES
                )
                .select_related("materiel")
            )

            conflits = []

            for reservation in reservations:

                materiel = reservation.materiel

                conflit = (
                    Reservation.objects
                    .filter(
                        materiel=materiel,
                        statut__in=services.ACTIVES,
                        date_sortie_prevue__lt=nouveau_fin,
                        date_retour_prevue__gt=nouveau_debut,
                    )
                    .exclude(pk=reservation.pk)
                    .exclude(projet=ancien)
                    .select_related("projet")
                    .first()
                )

                if conflit:

                    conflits.append(
                        f"{materiel.nom} : "
                        f"déjà réservé pour "
                        f"« {conflit.projet.nom} »"
                    )

                conflit_emprunt = (
                    Emprunt.objects
                    .filter(
                        materiel=materiel,
                        statut__in=services.EMPRUNTS_ACTIFS,
                        date_depart_prevue__lt=nouveau_fin,
                        date_retour_prevue__gt=nouveau_debut,
                    )
                    .select_related("utilisateur")
                    .first()
                )

                if conflit_emprunt:

                    conflits.append(
                        f"{materiel.nom} : "
                        "déjà emprunté sur cette période"
                    )

            if conflits:

                raise serializers.ValidationError({
                    "date_debut":
                        "Impossible de modifier les dates.",
                    "conflits":
                        conflits,
                })

        with transaction.atomic():

            projet = serializer.save()

            if dates_changees:

                projet.reservations.filter(
                    statut__in=services.ACTIVES
                ).update(
                    date_sortie_prevue=projet.date_debut,
                    date_retour_prevue=projet.date_fin,
                )

    # ========================================================
    # MATÉRIELS DISPONIBLES
    # ========================================================

    @action(
        detail=True,
        methods=["get"],
        url_path="materiels-disponibles",
    )
    def materiels_disponibles(
        self,
        request,
        pk=None,
    ):

        projet = self.get_object()

        # Seuls les matériels parents sont sélectionnables.
        materiels = (
            Materiel.objects
            .filter(
                kit_parent__isnull=True
            )
            .select_related("categorie")
            .order_by("nom")
        )

        deja_ids = set(
            projet.reservations
            .filter(
                statut__in=services.ACTIVES
            )
            .values_list(
                "materiel_id",
                flat=True,
            )
        )

        result = []

        for materiel in materiels:

            base = {
                "id": materiel.id,
                "nom": materiel.nom,
                "categorie_nom": (
                    materiel.categorie.nom
                    if materiel.categorie
                    else ""
                ),
                "qr_code": materiel.qr_code,
                "statut": materiel.statut,
                "disponible": False,
                "deja_dans_projet": False,
                "raison": None,
                "conflit_projet": None,
                "conflit_emprunt": None,
                "conflit_debut": None,
                "conflit_fin": None,
            }

            if materiel.id in deja_ids:

                base.update({
                    "disponible": True,
                    "deja_dans_projet": True,
                    "raison":
                        "Déjà dans ce projet",
                })

                result.append(base)

                continue

            if materiel.statut == (
                Materiel.Statut.HORS_SERVICE
            ):

                base["raison"] = "Hors service"

                result.append(base)

                continue

            if materiel.statut == (
                Materiel.Statut.MAINTENANCE
            ):

                base["raison"] = "En maintenance"

                result.append(base)

                continue

            conflit = (
                Reservation.objects
                .filter(
                    materiel=materiel,
                    statut__in=services.ACTIVES,
                    date_sortie_prevue__lt=projet.date_fin,
                    date_retour_prevue__gt=projet.date_debut,
                )
                .exclude(projet=projet)
                .select_related("projet")
                .first()
            )

            if conflit:

                base.update({
                    "raison":
                        "Déjà réservé sur cette période",
                    "conflit_projet":
                        conflit.projet.nom,
                    "conflit_debut":
                        conflit.date_sortie_prevue,
                    "conflit_fin":
                        conflit.date_retour_prevue,
                })

                result.append(base)

                continue

            conflit_emprunt = (
                Emprunt.objects
                .filter(
                    materiel=materiel,
                    statut__in=services.EMPRUNTS_ACTIFS,
                    date_depart_prevue__lt=projet.date_fin,
                    date_retour_prevue__gt=projet.date_debut,
                )
                .select_related("utilisateur")
                .first()
            )

            if conflit_emprunt:

                base.update({
                    "raison":
                        "Déjà emprunté sur cette période",
                    "conflit_emprunt":
                        str(
                            conflit_emprunt.utilisateur
                        ),
                    "conflit_debut":
                        conflit_emprunt.date_depart_prevue,
                    "conflit_fin":
                        conflit_emprunt.date_retour_prevue,
                })

                result.append(base)

                continue

            base["disponible"] = True

            result.append(base)

        return Response(result)

    # ========================================================
    # AJOUTER MATÉRIEL AU PROJET
    # ========================================================

    @action(
        detail=True,
        methods=["post"],
        url_path="ajouter-materiel",
    )
    def ajouter_materiel(
        self,
        request,
        pk=None,
    ):

        projet = self.get_object()

        ids = request.data.get(
            "materiel_ids",
            [],
        )

        if not isinstance(ids, list):

            return Response(
                {
                    "detail":
                        "materiel_ids doit être une liste."
                },
                status=400,
            )

        # On accepte uniquement les matériels parents.
        materiels = list(
            Materiel.objects
            .filter(
                pk__in=ids,
                kit_parent__isnull=True,
            )
        )

        deja = set(
            projet.reservations
            .filter(
                statut__in=services.ACTIVES
            )
            .values_list(
                "materiel_id",
                flat=True,
            )
        )

        erreurs = []
        a_creer = []

        for materiel in materiels:

            if materiel.pk in deja:
                continue

            if materiel.statut == (
                Materiel.Statut.HORS_SERVICE
            ):

                erreurs.append(
                    f"{materiel.nom} : hors service"
                )

                continue

            if materiel.statut == (
                Materiel.Statut.MAINTENANCE
            ):

                erreurs.append(
                    f"{materiel.nom} : en maintenance"
                )

                continue

            conflit = (
                Reservation.objects
                .filter(
                    materiel=materiel,
                    statut__in=services.ACTIVES,
                    date_sortie_prevue__lt=projet.date_fin,
                    date_retour_prevue__gt=projet.date_debut,
                )
                .exclude(projet=projet)
                .select_related("projet")
                .first()
            )

            if conflit:

                erreurs.append(
                    f"{materiel.nom} : déjà réservé "
                    f"pour « {conflit.projet.nom} »"
                )

                continue

            conflit_emprunt = (
                Emprunt.objects
                .filter(
                    materiel=materiel,
                    statut__in=services.EMPRUNTS_ACTIFS,
                    date_depart_prevue__lt=projet.date_fin,
                    date_retour_prevue__gt=projet.date_debut,
                )
                .select_related("utilisateur")
                .first()
            )

            if conflit_emprunt:

                erreurs.append(
                    f"{materiel.nom} : déjà emprunté "
                    "sur cette période"
                )

                continue

            a_creer.append(
                Reservation(
                    materiel=materiel,
                    projet=projet,
                    utilisateur=request.user,
                    date_sortie_prevue=
                        projet.date_debut,
                    date_retour_prevue=
                        projet.date_fin,
                )
            )

        if erreurs:

            return Response(
                {
                    "detail":
                        "Conflits : "
                        + " ; ".join(erreurs),
                    "conflits":
                        erreurs,
                },
                status=400,
            )

        with transaction.atomic():

            Reservation.objects.bulk_create(
                a_creer
            )

        return Response(
            self.get_serializer(
                self.get_object()
            ).data
        )

    # ========================================================
    # PDF KIT LIST
    # ========================================================

    @action(
        detail=True,
        methods=["get"],
        url_path="kit-list",
    )
    def kit_list(
        self,
        request,
        pk=None,
    ):

        projet = self.get_object()

        st = getSampleStyleSheet()

        buf = BytesIO()

        doc = SimpleDocTemplate(
            buf,
            pagesize=A4,
            title=f"Kit list - {projet.nom}",
        )

        loc = timezone.localtime

        story = [
            Paragraph(
                f"Kit list — {projet.nom}",
                st["Title"],
            ),
            Paragraph(
                f"Lieu : {projet.lieu or '-'} | "
                f"Du {loc(projet.date_debut):%d/%m/%Y} "
                f"au {loc(projet.date_fin):%d/%m/%Y} | "
                f"Responsable : {projet.responsable}",
                st["Normal"],
            ),
            Spacer(1, 14),
        ]

        rows = [[
            "#",
            "Matériel",
            "N° série",
            "Code",
            "Sorti",
            "Rendu",
        ]]

        reservations = (
            projet.reservations
            .exclude(
                statut=Reservation.Statut.ANNULEE
            )
            .select_related("materiel")
        )

        for i, reservation in enumerate(
            reservations,
            1,
        ):

            materiel = reservation.materiel

            rows.append([
                i,
                Paragraph(
                    materiel.nom,
                    st["Normal"],
                ),
                materiel.numero_serie,
                materiel.qr_code,
                "[   ]",
                "[   ]",
            ])

        table = Table(
            rows,
            colWidths=[
                24,
                190,
                90,
                90,
                40,
                40,
            ],
            repeatRows=1,
        )

        table.setStyle(
            TableStyle([
                (
                    "BACKGROUND",
                    (0, 0),
                    (-1, 0),
                    colors.HexColor("#3949ab"),
                ),
                (
                    "TEXTCOLOR",
                    (0, 0),
                    (-1, 0),
                    colors.white,
                ),
                (
                    "GRID",
                    (0, 0),
                    (-1, -1),
                    0.4,
                    colors.grey,
                ),
                (
                    "VALIGN",
                    (0, 0),
                    (-1, -1),
                    "MIDDLE",
                ),
                (
                    "FONTSIZE",
                    (0, 0),
                    (-1, -1),
                    8,
                ),
            ])
        )

        story.append(table)

        doc.build(story)

        response = HttpResponse(
            buf.getvalue(),
            content_type="application/pdf",
        )

        response[
            "Content-Disposition"
        ] = (
            f'attachment; filename="kit-list-{projet.pk}.pdf"'
        )

        return response


# ============================================================
# RESERVATIONS
# ============================================================

class ReservationViewSet(
    viewsets.ModelViewSet
):

    queryset = Reservation.objects.select_related(
        "materiel",
        "projet",
        "utilisateur",
    )

    serializer_class = ReservationSerializer

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
    ]

    filterset_fields = [
        "projet",
        "materiel",
        "statut",
        "utilisateur",
    ]

    def _validate_root_material(
        self,
        materiel,
    ):

        if materiel.kit_parent_id:

            raise serializers.ValidationError({
                "materiel": (
                    "Un équipement associé ne peut pas "
                    "être réservé séparément. "
                    "Sélectionnez le matériel parent."
                )
            })

    def perform_create(
        self,
        serializer,
    ):

        materiel = serializer.validated_data[
            "materiel"
        ]

        self._validate_root_material(
            materiel
        )

        serializer.save(
            utilisateur=self.request.user
        )

    def perform_update(
        self,
        serializer,
    ):

        materiel = serializer.validated_data.get(
            "materiel",
            serializer.instance.materiel,
        )

        self._validate_root_material(
            materiel
        )

        serializer.save()

    def _do(
        self,
        res,
        fn,
        *args,
    ):

        try:

            result = fn(
                res,
                *args,
            )

            res.refresh_from_db()

            return Response({
                "reservation":
                    self.get_serializer(
                        res
                    ).data,
                "manquants":
                    result or [],
            })

        except ValueError as e:

            return Response(
                {
                    "detail":
                        str(e)
                },
                status=400,
            )

    @action(
        detail=True,
        methods=["post"],
        url_path="check-out",
    )
    def check_out(
        self,
        request,
        pk=None,
    ):

        return self._do(
            self.get_object(),
            services.check_out,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="check-in",
    )
    def check_in(
        self,
        request,
        pk=None,
    ):

        return self._do(
            self.get_object(),
            services.check_in,
            request.data.get(
                "notes",
                "",
            ),
        )

    @action(
        detail=True,
        methods=["post"],
    )
    def annuler(
        self,
        request,
        pk=None,
    ):

        reservation = self.get_object()

        if reservation.statut == (
            Reservation.Statut.RETOURNEE
        ):

            return Response(
                {
                    "detail":
                        "Une réservation retournée "
                        "ne peut plus être annulée."
                },
                status=400,
            )

        reservation.statut = (
            Reservation.Statut.ANNULEE
        )

        reservation.save(
            update_fields=["statut"]
        )

        services._restore_material_status(
            reservation.materiel
        )

        return Response(
            self.get_serializer(
                reservation
            ).data
        )

    @action(
        detail=False,
        methods=["post"],
    )
    def scan(
        self,
        request,
    ):

        materiel = get_object_or_404(
            Materiel,
            qr_code=request.data.get(
                "qr_code",
                "",
            ),
            kit_parent__isnull=True,
        )

        sortie = (
            request.data.get("action")
            == "out"
        )

        qs = Reservation.objects.filter(
            materiel=materiel,
            statut=(
                Reservation.Statut.RESERVEE
                if sortie
                else Reservation.Statut.SORTIE
            ),
        )

        if sortie:

            qs = qs.filter(
                date_sortie_prevue__lte=(
                    timezone.now()
                    + timedelta(days=1)
                )
            )

        reservation = (
            qs.order_by(
                "date_sortie_prevue"
            ).first()
        )

        if not reservation:

            msg = (
                "Aucune réservation à sortir"
                if sortie
                else "Ce matériel n'est pas sorti"
            )

            return Response(
                {
                    "detail":
                        f"{msg} pour {materiel.nom}."
                },
                status=404,
            )

        if sortie:

            return self._do(
                reservation,
                services.check_out,
            )

        return self._do(
            reservation,
            services.check_in,
            request.data.get(
                "notes",
                "",
            ),
        )


# ============================================================
# EMPRUNTS
# ============================================================

class EmpruntViewSet(
    viewsets.ModelViewSet
):

    queryset = Emprunt.objects.select_related(
        "materiel",
        "utilisateur",
        "created_by",
    )

    serializer_class = EmpruntSerializer

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
        "utilisateur",
        "statut",
    ]

    search_fields = [
        "materiel__nom",
        "materiel__qr_code",
        "motif",
        "notes",
    ]

    def _validate_root_material(
        self,
        materiel,
    ):

        if materiel.kit_parent_id:

            raise serializers.ValidationError({
                "materiel": (
                    "Un équipement associé ne peut pas "
                    "être emprunté séparément. "
                    "Sélectionnez le matériel parent."
                )
            })

    def perform_create(
        self,
        serializer,
    ):

        materiel = serializer.validated_data[
            "materiel"
        ]

        self._validate_root_material(
            materiel
        )

        serializer.save(
            created_by=self.request.user
        )

    def perform_update(
        self,
        serializer,
    ):

        materiel = serializer.validated_data.get(
            "materiel",
            serializer.instance.materiel,
        )

        self._validate_root_material(
            materiel
        )

        serializer.save()

    def _do(
        self,
        emprunt,
        fn,
        *args,
    ):

        try:

            fn(
                emprunt,
                *args,
            )

            emprunt.refresh_from_db()

            return Response(
                self.get_serializer(
                    emprunt
                ).data
            )

        except ValueError as e:

            return Response(
                {
                    "detail":
                        str(e)
                },
                status=400,
            )

    @action(
        detail=True,
        methods=["post"],
        url_path="start",
    )
    def start(
        self,
        request,
        pk=None,
    ):

        return self._do(
            self.get_object(),
            services.start_emprunt,
        )

    @action(
        detail=True,
        methods=["post"],
        url_path="return",
    )
    def return_item(
        self,
        request,
        pk=None,
    ):

        return self._do(
            self.get_object(),
            services.return_emprunt,
            request.data.get(
                "notes",
                "",
            ),
        )

    @action(
        detail=True,
        methods=["post"],
    )
    def annuler(
        self,
        request,
        pk=None,
    ):

        return self._do(
            self.get_object(),
            services.cancel_emprunt,
        )

    @action(
        detail=False,
        methods=["post"],
        url_path="scan",
    )
    def scan(
        self,
        request,
    ):

        materiel = get_object_or_404(
            Materiel,
            qr_code=request.data.get(
                "qr_code",
                "",
            ),
            kit_parent__isnull=True,
        )

        action_name = request.data.get(
            "action",
            "out",
        )

        if action_name == "out":

            emprunt = (
                Emprunt.objects.filter(
                    materiel=materiel,
                    statut=Emprunt.Statut.PLANIFIE,
                )
                .order_by(
                    "date_depart_prevue"
                )
                .first()
            )

            if not emprunt:

                return Response(
                    {
                        "detail":
                            f"Aucun emprunt à sortir "
                            f"pour {materiel.nom}."
                    },
                    status=404,
                )

            return self._do(
                emprunt,
                services.start_emprunt,
            )

        emprunt = (
            Emprunt.objects.filter(
                materiel=materiel,
                statut__in=(
                    Emprunt.Statut.EN_COURS,
                    Emprunt.Statut.EN_RETARD,
                ),
            )
            .order_by(
                "date_depart_prevue"
            )
            .first()
        )

        if not emprunt:

            return Response(
                {
                    "detail":
                        f"Aucun emprunt en cours "
                        f"pour {materiel.nom}."
                },
                status=404,
            )

        return self._do(
            emprunt,
            services.return_emprunt,
            request.data.get(
                "notes",
                "",
            ),
        )


# ============================================================
# NOTIFICATIONS
# ============================================================

class NotificationViewSet(viewsets.ModelViewSet):
    """
    Gestion des notifications personnelles.

    GET    /notifications/
    GET    /notifications/<id>/
    DELETE /notifications/<id>/

    POST /notifications/envoyer/
        destinataire:
            - tout_le_monde
            - administrateur
            - equipe
            - utilisateur

        cible:
            - tous
            - ID utilisateur
    """

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    http_method_names = [
        "get",
        "post",
        "delete",
        "head",
        "options",
    ]

    def get_queryset(self):
        """
        Un utilisateur ne voit que ses propres notifications.
        """
        return Notification.objects.filter(
            utilisateur=self.request.user
        ).order_by("-created")

    # ============================================================
    # MARQUER UNE NOTIFICATION COMME LUE
    # ============================================================

    @action(
        detail=True,
        methods=["post"],
        url_path="lire",
    )
    def lire(self, request, pk=None):
        notification = self.get_object()

        notification.lu = True
        notification.save(
            update_fields=["lu"]
        )

        return Response(
            {
                "detail": "Notification marquée comme lue."
            },
            status=status.HTTP_200_OK,
        )

    # ============================================================
    # MARQUER TOUTES LES NOTIFICATIONS COMME LUES
    # ============================================================

    @action(
        detail=False,
        methods=["post"],
        url_path="tout-lire",
    )
    def tout_lire(self, request):
        count = Notification.objects.filter(
            utilisateur=request.user,
            lu=False,
        ).update(lu=True)

        return Response(
            {
                "detail": "Toutes les notifications ont été marquées comme lues.",
                "count": count,
            },
            status=status.HTTP_200_OK,
        )

    # ============================================================
    # ENVOYER UNE NOTIFICATION
    # ============================================================

    @action(
        detail=False,
        methods=["post"],
        url_path="envoyer",
    )
    def envoyer(self, request):
        """
        Envoi d'une notification par un administrateur.

        Exemple:

        {
            "destinataire": "tout_le_monde",
            "cible": "tous",
            "titre": "Information",
            "message": "Bonjour à tous."
        }

        ou:

        {
            "destinataire": "administrateur",
            "cible": "tous",
            "titre": "Information",
            "message": "Message pour les administrateurs."
        }

        ou:

        {
            "destinataire": "equipe",
            "cible": "tous",
            "titre": "Information",
            "message": "Message pour l'équipe."
        }

        ou:

        {
            "destinataire": "utilisateur",
            "cible": 15,
            "titre": "Urgent",
            "message": "Votre matériel..."
        }
        """

        # --------------------------------------------------------
        # Vérification administrateur
        # --------------------------------------------------------

        if getattr(request.user, "role", None) != "admin":
            return Response(
                {
                    "detail": "Seuls les administrateurs peuvent envoyer des notifications."
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # --------------------------------------------------------
        # Récupération des données
        # --------------------------------------------------------

        destinataire = str(
            request.data.get(
                "destinataire",
                ""
            )
        ).strip().lower()

        cible = request.data.get("cible")

        titre = str(
            request.data.get(
                "titre",
                ""
            )
        ).strip()

        message = str(
            request.data.get(
                "message",
                ""
            )
        ).strip()

        # --------------------------------------------------------
        # Validation titre
        # --------------------------------------------------------

        if not titre:
            return Response(
                {
                    "titre": "Le titre est obligatoire."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # --------------------------------------------------------
        # Validation message
        # --------------------------------------------------------

        if not message:
            return Response(
                {
                    "message": "Le message est obligatoire."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # --------------------------------------------------------
        # Validation destinataire
        # --------------------------------------------------------

        destinataires_valides = {
            "tout_le_monde",
            "administrateur",
            "equipe",
            "utilisateur",
        }

        if destinataire not in destinataires_valides:
            return Response(
                {
                    "destinataire": (
                        "Destinataire invalide. "
                        "Valeurs acceptées : "
                        "tout_le_monde, administrateur, equipe, utilisateur."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # --------------------------------------------------------
        # Import User
        # --------------------------------------------------------

        from django.contrib.auth import get_user_model

        User = get_user_model()

        # --------------------------------------------------------
        # Détermination des utilisateurs
        # --------------------------------------------------------

        utilisateurs = User.objects.filter(
            is_active=True
        )

        # ========================================================
        # TOUT LE MONDE
        # ========================================================

        if destinataire == "tout_le_monde":

            # Pour cette catégorie, on force "tous".
            if cible not in (
                None,
                "",
                "tous",
                "tout_le_monde",
            ):
                return Response(
                    {
                        "cible": (
                            "Pour 'Tout le monde', "
                            "la cible doit être 'tous'."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # ========================================================
        # ADMINISTRATEURS
        # ========================================================

        elif destinataire == "administrateur":

            if cible in (
                None,
                "",
                "tous",
                "tous_les_administrateurs",
            ):
                utilisateurs = utilisateurs.filter(
                    role="admin"
                )

            else:
                try:
                    user_id = int(cible)
                except (
                    TypeError,
                    ValueError,
                ):
                    return Response(
                        {
                            "cible": "Identifiant utilisateur invalide."
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                utilisateurs = utilisateurs.filter(
                    id=user_id,
                    role="admin",
                )

        # ========================================================
        # ÉQUIPE
        # ========================================================

        elif destinataire == "equipe":

            if cible in (
                None,
                "",
                "tous",
                "toutes_les_equipes",
            ):
                utilisateurs = utilisateurs.filter(
                    role="equipe"
                )

            else:
                try:
                    user_id = int(cible)
                except (
                    TypeError,
                    ValueError,
                ):
                    return Response(
                        {
                            "cible": "Identifiant utilisateur invalide."
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                utilisateurs = utilisateurs.filter(
                    id=user_id,
                    role="equipe",
                )

        # ========================================================
        # UTILISATEUR SIMPLE
        # ========================================================

        elif destinataire == "utilisateur":

            if cible in (
                None,
                "",
                "tous",
                "tous_les_utilisateurs",
            ):
                utilisateurs = utilisateurs.filter(
                    role="utilisateur"
                )

            else:
                try:
                    user_id = int(cible)
                except (
                    TypeError,
                    ValueError,
                ):
                    return Response(
                        {
                            "cible": "Identifiant utilisateur invalide."
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                utilisateurs = utilisateurs.filter(
                    id=user_id,
                    role="utilisateur",
                )

        # --------------------------------------------------------
        # Vérifier qu'il existe des destinataires
        # --------------------------------------------------------

        utilisateurs = list(
            utilisateurs
        )

        if not utilisateurs:
            return Response(
                {
                    "detail": (
                        "Aucun utilisateur correspondant "
                        "au destinataire sélectionné."
                    )
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # --------------------------------------------------------
        # Création des notifications
        # --------------------------------------------------------

        from uuid import uuid4

        notifications = []

        for utilisateur in utilisateurs:
            notifications.append(
                Notification(
                    utilisateur=utilisateur,
                    titre=titre,
                    message=message,
                    lu=False,
                    cle=(
                        f"admin-{request.user.id}-"
                        f"{uuid4().hex}"
                    ),
                )
            )

        Notification.objects.bulk_create(
            notifications
        )

        # --------------------------------------------------------
        # Réponse
        # --------------------------------------------------------

        return Response(
            {
                "detail": "Notification envoyée avec succès.",
                "destinataire": destinataire,
                "cible": cible or "tous",
                "nombre_destinataires": len(
                    notifications
                ),
            },
            status=status.HTTP_201_CREATED,
        )
    
# ============================================================
# DASHBOARD
# ============================================================

class DashboardView(APIView):

    def get(
        self,
        request,
    ):

        now = timezone.now()

        today = timezone.localdate()

        # ====================================================
        # IMPORTANT
        # ====================================================
        #
        # Seuls les matériels parents entrent dans le parc.
        #
        # Exemple :
        #
        # Drone DJI
        # ├── Batterie
        # ├── Radiocommande
        # └── Hélices
        #
        # Le Drone est le matériel.
        # Les équipements ne sont pas des matériels autonomes.
        #
        # ====================================================

        mats = Materiel.objects.filter(
            kit_parent__isnull=True
        )

        # ====================================================
        # TOTAL
        # ====================================================

        total = mats.count()

        # ====================================================
        # RÉPARTITION PAR STATUT
        # ====================================================

        par_statut = {
            statut: 0
            for statut, _
            in Materiel.Statut.choices
        }

        for row in (
            mats
            .values("statut")
            .annotate(
                n=Count("id")
            )
        ):

            par_statut[
                row["statut"]
            ] = row["n"]

        # ====================================================
        # SORTIES EN COURS
        # ====================================================

        sorties = (
            Reservation.objects
            .filter(
                statut=Reservation.Statut.SORTIE
            )
            .select_related(
                "materiel",
                "projet",
            )
        )

        # ====================================================
        # EMPRUNTS EN COURS
        # ====================================================

        emprunts_actifs = (
            Emprunt.objects
            .filter(
                statut__in=(
                    Emprunt.Statut.EN_COURS,
                    Emprunt.Statut.EN_RETARD,
                )
            )
            .select_related(
                "materiel",
                "utilisateur",
            )
        )

        # ====================================================
        # RETARDS PROJETS
        # ====================================================

        retards_projet = [

            {
                "id":
                    r.id,

                "materiel":
                    r.materiel.nom,

                "materiel_id":
                    r.materiel_id,

                "projet":
                    r.projet.nom,

                "projet_id":
                    r.projet_id,

                "emprunteur":
                    None,

                "date_sortie_prevue":
                    r.date_sortie_prevue,

                "date_retour_prevue":
                    r.date_retour_prevue,

                "type":
                    "projet",
            }

            for r in sorties.filter(
                date_retour_prevue__lt=now
            )

            if r.materiel.kit_parent_id is None
        ]

        # ====================================================
        # RETARDS EMPRUNTS
        # ====================================================

        retards_emprunt = [

            {
                "id":
                    e.id,

                "materiel":
                    e.materiel.nom,

                "materiel_id":
                    e.materiel_id,

                "projet":
                    None,

                "projet_id":
                    None,

                "emprunteur":
                    str(e.utilisateur),

                "date_sortie_prevue":
                    e.date_depart_prevue,

                "date_retour_prevue":
                    e.date_retour_prevue,

                "type":
                    "emprunt",
            }

            for e in emprunts_actifs.filter(
                date_retour_prevue__lt=now
            )

            if e.materiel.kit_parent_id is None
        ]

        retards = (
            retards_projet
            +
            retards_emprunt
        )

        # ====================================================
        # RETOURS PRÉVUS AUJOURD'HUI
        # ====================================================

        retours_projet = [

            {
                "materiel":
                    r.materiel.nom,

                "projet":
                    r.projet.nom,

                "emprunteur":
                    None,

                "date_retour_prevue":
                    r.date_retour_prevue,

                "type":
                    "projet",
            }

            for r in Reservation.objects.filter(
                statut=Reservation.Statut.SORTIE,
                date_retour_prevue__date=today,
                materiel__kit_parent__isnull=True,
            ).select_related(
                "materiel",
                "projet",
            )
        ]

        retours_emprunt = [

            {
                "materiel":
                    e.materiel.nom,

                "projet":
                    None,

                "emprunteur":
                    str(e.utilisateur),

                "date_retour_prevue":
                    e.date_retour_prevue,

                "type":
                    "emprunt",
            }

            for e in Emprunt.objects.filter(
                statut__in=(
                    Emprunt.Statut.EN_COURS,
                    Emprunt.Statut.EN_RETARD,
                ),
                date_retour_prevue__date=today,
                materiel__kit_parent__isnull=True,
            ).select_related(
                "materiel",
                "utilisateur",
            )
        ]

        # ====================================================
        # TOURNAGES À PRÉPARER
        # ====================================================

        tournages_a_preparer = (
            Projet.objects
            .filter(
                statut=Projet.Statut.PREPARATION
            )
            .order_by(
                "date_debut"
            )
        )

        # ====================================================
        # MAINTENANCE EN COURS
        # ====================================================

        maintenance_en_cours = (
            Materiel.objects
            .filter(
                kit_parent__isnull=True,
                statut=Materiel.Statut.MAINTENANCE,
            )
            .select_related(
                "categorie"
            )
            .order_by(
                "nom"
            )
        )

        # ====================================================
        # RÉPONSE
        # ====================================================

        return Response({

            # ------------------------------
            # STATISTIQUES
            # ------------------------------

            "total":
                total,

            "par_statut":
                par_statut,

            # ------------------------------
            # RETARDS
            # ------------------------------

            "en_retard":
                len(retards),

            "retards":
                retards,

            # ------------------------------
            # RETOURS DU JOUR
            # ------------------------------

            "retours_du_jour":
                retours_projet
                +
                retours_emprunt,

            # ------------------------------
            # TOURNAGES À PRÉPARER
            # ------------------------------

            "sorties_a_preparer": [

                {
                    "id":
                        p.id,

                    "nom":
                        p.nom,

                    "date_debut":
                        p.date_debut,

                    "date_fin":
                        p.date_fin,
                }

                for p in tournages_a_preparer
            ],

            # ------------------------------
            # MAINTENANCE EN COURS
            # ------------------------------

            "maintenance_en_cours": [

                {
                    "id":
                        m.id,

                    "nom":
                        m.nom,

                    "categorie":
                        (
                            m.categorie.nom
                            if m.categorie
                            else ""
                        ),

                    "statut":
                        m.statut,
                }

                for m in maintenance_en_cours
            ],
        })