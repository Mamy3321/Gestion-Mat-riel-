from django.db.models import Q

from rest_framework import (
    status,
    viewsets,
)

from rest_framework.parsers import (
    MultiPartParser,
    FormParser,
    JSONParser,
)

from rest_framework.permissions import (
    IsAuthenticated,
)

from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework_simplejwt.views import (
    TokenObtainPairView,
)

from bookings.models import Notification

from .models import User

from .serializers import (
    LoginSerializer,
    UserSerializer,
    RegisterSerializer,
    ProfileSerializer,
    AdminUserSerializer,
)


# ============================================================
# LOGIN
# ============================================================

class LoginView(TokenObtainPairView):

    serializer_class = LoginSerializer


# ============================================================
# CREATION DE COMPTE
# ============================================================

class RegisterView(APIView):

    permission_classes = []

    def post(
        self,
        request,
    ):

        serializer = RegisterSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        user = serializer.save()

        return Response(
            {
                "message": (
                    "Votre compte a été créé avec succès. "
                    "Il est maintenant en attente de validation "
                    "par un administrateur."
                ),
                "user": UserSerializer(
                    user
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )


# ============================================================
# UTILISATEUR CONNECTÉ
# ============================================================

class MeView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def get(
        self,
        request,
    ):

        return Response(
            UserSerializer(
                request.user
            ).data
        )


# ============================================================
# PROFIL
# ============================================================

class ProfileView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    parser_classes = [
        MultiPartParser,
        FormParser,
        JSONParser,
    ]

    def get(
        self,
        request,
    ):

        serializer = ProfileSerializer(
            request.user
        )

        return Response(
            serializer.data,
            status=status.HTTP_200_OK,
        )

    def patch(
        self,
        request,
    ):

        serializer = ProfileSerializer(
            request.user,
            data=request.data,
            partial=True,
        )

        serializer.is_valid(
            raise_exception=True
        )

        user = serializer.save()

        return Response(
            ProfileSerializer(
                user
            ).data,
            status=status.HTTP_200_OK,
        )

    def delete(
        self,
        request,
    ):

        user = request.user

        user.delete()

        return Response(
            {
                "message":
                    "Compte supprimé avec succès."
            },
            status=status.HTTP_200_OK,
        )


# ============================================================
# ADMIN CHECK
# ============================================================

def is_admin(user):

    return (
        user.is_authenticated
        and user.role == User.Role.ADMIN
    )


# ============================================================
# APPROUVER UN COMPTE
# ============================================================

class ApproveUserView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(
        self,
        request,
        pk,
    ):

        # ----------------------------------------------------
        # VERIFICATION ADMIN
        # ----------------------------------------------------

        if not is_admin(request.user):

            return Response(
                {
                    "detail":
                        "Accès réservé aux administrateurs."
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # ----------------------------------------------------
        # RECHERCHE UTILISATEUR
        # ----------------------------------------------------

        try:

            user = User.objects.get(
                pk=pk
            )

        except User.DoesNotExist:

            return Response(
                {
                    "detail":
                        "Utilisateur introuvable."
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # ----------------------------------------------------
        # VALIDATION
        # ----------------------------------------------------

        user.validation_status = (
            User.ValidationStatus.APPROVED
        )

        user.is_active = True

        user.save(
            update_fields=[
                "validation_status",
                "is_active",
            ]
        )

        # ----------------------------------------------------
        # IDENTIFIANT AUTOMATIQUE
        # ----------------------------------------------------
        #
        # L'identifiant est déjà généré lors de
        # l'inscription dans RegisterSerializer.
        #
        # Exemple :
        #
        # email    = mamy.ernest@gmail.com
        # username = mamy.ernest
        #
        # On récupère donc simplement user.username.
        # ----------------------------------------------------

        identifiant = user.username

        # ----------------------------------------------------
        # NOTIFICATION PRIVEE
        # ----------------------------------------------------
        #
        # La notification appartient uniquement
        # à l'utilisateur qui vient d'être validé.
        #
        # get_or_create évite les doublons.
        # ----------------------------------------------------

        notification, notification_created = (
            Notification.objects.get_or_create(

                utilisateur=user,

                cle=f"compte-valide-{user.pk}",

                defaults={
                    "titre":
                        "Compte validé",

                    "message":
                        (
                            "Votre compte a été validé avec succès. "
                            f"Votre identifiant est : {identifiant}"
                        ),
                },
            )
        )

        # ----------------------------------------------------
        # REPONSE
        # ----------------------------------------------------

        return Response(
            {
                "message":
                    "Compte validé avec succès.",

                "identifiant":
                    identifiant,

                "notification":
                    {
                        "id":
                            notification.id,

                        "titre":
                            notification.titre,

                        "message":
                            notification.message,

                        "lu":
                            notification.lu,

                        "created":
                            notification.created,
                    },

                "user":
                    AdminUserSerializer(
                        user
                    ).data,
            },

            status=status.HTTP_200_OK,
        )


# ============================================================
# REFUSER UN COMPTE
# ============================================================

class RejectUserView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(
        self,
        request,
        pk,
    ):

        if not is_admin(request.user):

            return Response(
                {
                    "detail":
                        "Accès réservé aux administrateurs."
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        try:

            user = User.objects.get(
                pk=pk
            )

        except User.DoesNotExist:

            return Response(
                {
                    "detail":
                        "Utilisateur introuvable."
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # ----------------------------------------------------
        # PROTECTION ADMIN
        # ----------------------------------------------------

        if user.pk == request.user.pk:

            return Response(
                {
                    "detail":
                        "Vous ne pouvez pas refuser votre propre compte."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ----------------------------------------------------
        # REFUS
        # ----------------------------------------------------

        user.validation_status = (
            User.ValidationStatus.REJECTED
        )

        user.is_active = False

        user.save(
            update_fields=[
                "validation_status",
                "is_active",
            ]
        )

        return Response(
            {
                "message":
                    "Compte refusé.",

                "user":
                    AdminUserSerializer(
                        user
                    ).data,
            }
        )


# ============================================================
# GESTION DES UTILISATEURS
# ============================================================

class UserViewSet(viewsets.ModelViewSet):

    queryset = User.objects.all().order_by(
        "username"
    )

    serializer_class = AdminUserSerializer

    permission_classes = [
        IsAuthenticated
    ]

    pagination_class = None

    filterset_fields = [
        "role",
        "validation_status",
    ]

    search_fields = [
        "username",
        "first_name",
        "last_name",
        "email",
    ]

    def _check_admin(
        self,
        request,
    ):

        if not is_admin(
            request.user
        ):

            return Response(
                {
                    "detail":
                        "Accès réservé aux administrateurs."
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        return None

    def list(
        self,
        request,
        *args,
        **kwargs,
    ):

        error = self._check_admin(
            request
        )

        if error:
            return error

        return super().list(
            request,
            *args,
            **kwargs,
        )

    def retrieve(
        self,
        request,
        *args,
        **kwargs,
    ):

        error = self._check_admin(
            request
        )

        if error:
            return error

        return super().retrieve(
            request,
            *args,
            **kwargs,
        )

    def update(
        self,
        request,
        *args,
        **kwargs,
    ):

        error = self._check_admin(
            request
        )

        if error:
            return error

        user = self.get_object()

        if user.pk == request.user.pk:

            new_role = request.data.get(
                "role"
            )

            if (
                new_role
                and new_role != User.Role.ADMIN
            ):

                return Response(
                    {
                        "detail":
                            "Vous ne pouvez pas retirer votre propre rôle Admin."
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        return super().update(
            request,
            *args,
            **kwargs,
        )

    def partial_update(
        self,
        request,
        *args,
        **kwargs,
    ):

        error = self._check_admin(
            request
        )

        if error:
            return error

        user = self.get_object()

        if user.pk == request.user.pk:

            new_role = request.data.get(
                "role"
            )

            if (
                new_role
                and new_role != User.Role.ADMIN
            ):

                return Response(
                    {
                        "detail":
                            "Vous ne pouvez pas retirer votre propre rôle Admin."
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        return super().partial_update(
            request,
            *args,
            **kwargs,
        )

    def destroy(
        self,
        request,
        *args,
        **kwargs,
    ):

        error = self._check_admin(
            request
        )

        if error:
            return error

        user = self.get_object()

        if user.pk == request.user.pk:

            return Response(
                {
                    "detail":
                        "Vous ne pouvez pas supprimer votre propre compte depuis cette interface."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.delete()

        return Response(
            {
                "message":
                    "Utilisateur supprimé avec succès."
            },
            status=status.HTTP_200_OK,
        )

    # --------------------------------------------------------
    # PAS DE CREATE
    # --------------------------------------------------------

    def create(
        self,
        request,
        *args,
        **kwargs,
    ):

        return Response(
            {
                "detail":
                    "La création des comptes se fait via l'inscription."
            },
            status=status.HTTP_405_METHOD_NOT_ALLOWED,
        )