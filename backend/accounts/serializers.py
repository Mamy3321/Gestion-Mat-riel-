from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import User


# ============================================================
# USER SERIALIZER
# ============================================================

class UserSerializer(serializers.ModelSerializer):

    nom_complet = serializers.SerializerMethodField()

    photo = serializers.ImageField(
        required=False,
        allow_null=True,
    )

    class Meta:
        model = User

        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "validation_status",
            "nom_complet",
            "photo",
        ]

        read_only_fields = [
            "id",
            "username",
            "role",
            "validation_status",
            "nom_complet",
        ]

    def get_nom_complet(self, obj):
        return (
            obj.get_full_name()
            or obj.username
        )


# ============================================================
# REGISTER SERIALIZER
# ============================================================

class RegisterSerializer(serializers.ModelSerializer):

    password = serializers.CharField(
        write_only=True,
        min_length=8,
    )

    password_confirmation = serializers.CharField(
        write_only=True,
    )

    role = serializers.ChoiceField(
        choices=[
            (
                User.Role.EQUIPE,
                User.Role.EQUIPE.label,
            ),
            (
                User.Role.UTILISATEUR,
                User.Role.UTILISATEUR.label,
            ),
        ]
    )

    class Meta:
        model = User

        fields = [
            "first_name",
            "last_name",
            "email",
            "role",
            "password",
            "password_confirmation",
        ]

    # --------------------------------------------------------
    # VALIDATION EMAIL
    # --------------------------------------------------------

    def validate_email(self, value):

        email = value.strip().lower()

        if not email:
            raise serializers.ValidationError(
                "L'adresse email est obligatoire."
            )

        if User.objects.filter(
            email__iexact=email
        ).exists():
            raise serializers.ValidationError(
                "Cette adresse email est déjà utilisée."
            )

        return email

    # --------------------------------------------------------
    # VALIDATION GENERALE
    # --------------------------------------------------------

    def validate(self, attrs):

        if attrs["password"] != attrs["password_confirmation"]:
            raise serializers.ValidationError({
                "password_confirmation":
                    "Les mots de passe ne correspondent pas."
            })

        return attrs

    # --------------------------------------------------------
    # GENERATION USERNAME
    # --------------------------------------------------------

    def _generate_username(self, email):

        # Partie avant @
        base = email.split("@")[0].strip().lower()

        # Nettoyage des caractères non autorisés
        username = ""

        for char in base:
            if char.isalnum() or char in "._-":
                username += char

        # Sécurité si le résultat est vide
        if not username:
            username = "user"

        original = username
        counter = 1

        # Vérifie l'unicité
        while User.objects.filter(
            username__iexact=username
        ).exists():

            username = f"{original}{counter}"
            counter += 1

        return username

    # --------------------------------------------------------
    # CREATION COMPTE
    # --------------------------------------------------------

    def create(self, validated_data):

        # Retirer confirmation
        validated_data.pop(
            "password_confirmation"
        )

        # Récupérer password
        password = validated_data.pop(
            "password"
        )

        # Email normalisé
        email = validated_data.get(
            "email",
            ""
        ).strip().lower()

        validated_data["email"] = email

        # Génération automatique de l'identifiant
        username = self._generate_username(email)

        # Création utilisateur
        user = User(
            username=username,
            **validated_data,
        )

        # ----------------------------------------------------
        # COMPTE EN ATTENTE
        # ----------------------------------------------------

        user.validation_status = (
            User.ValidationStatus.PENDING
        )

        # Impossible de se connecter avant validation Admin
        user.is_active = False

        # Mot de passe sécurisé
        user.set_password(password)

        user.save()

        return user


# ============================================================
# PROFILE SERIALIZER
# ============================================================

class ProfileSerializer(serializers.ModelSerializer):

    nom_complet = serializers.SerializerMethodField()

    photo = serializers.ImageField(
        required=False,
        allow_null=True,
    )

    class Meta:
        model = User

        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "validation_status",
            "photo",
            "nom_complet",
        ]

        read_only_fields = [
            "id",
            "username",
            "role",
            "validation_status",
            "nom_complet",
        ]

    def get_nom_complet(self, obj):
        return (
            obj.get_full_name()
            or obj.username
        )

    def update(
        self,
        instance,
        validated_data,
    ):

        if "first_name" in validated_data:
            instance.first_name = (
                validated_data["first_name"].strip()
            )

        if "last_name" in validated_data:
            instance.last_name = (
                validated_data["last_name"].strip()
            )

        if "email" in validated_data:

            email = (
                validated_data["email"]
                .strip()
                .lower()
            )

            # Vérifier qu'aucun autre utilisateur
            # n'utilise déjà cet email.
            if User.objects.filter(
                email__iexact=email
            ).exclude(
                pk=instance.pk
            ).exists():

                raise serializers.ValidationError({
                    "email":
                        "Cette adresse email est déjà utilisée."
                })

            instance.email = email

        if "photo" in validated_data:
            instance.photo = validated_data["photo"]

        instance.save()

        return instance


# ============================================================
# ADMIN - USER MANAGEMENT
# ============================================================

class AdminUserSerializer(serializers.ModelSerializer):

    nom_complet = serializers.SerializerMethodField()

    class Meta:
        model = User

        fields = [
            "id",
            "username",
            "first_name",
            "last_name",
            "email",
            "role",
            "validation_status",
            "is_active",
            "nom_complet",
            "photo",
        ]

        read_only_fields = [
            "id",
            "username",
            "validation_status",
            "is_active",
            "nom_complet",
        ]

    def get_nom_complet(self, obj):
        return (
            obj.get_full_name()
            or obj.username
        )


# ============================================================
# LOGIN SERIALIZER
# ============================================================

class LoginSerializer(TokenObtainPairSerializer):

    def validate(self, attrs):

        data = super().validate(attrs)

        data["user"] = UserSerializer(
            self.user
        ).data

        return data