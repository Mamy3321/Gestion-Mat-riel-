from rest_framework.permissions import (
    SAFE_METHODS,
    BasePermission,
)


class RolePermission(BasePermission):
    """
    Lecture pour tout utilisateur connecté.
    Écriture selon view.write_roles.
    """

    def has_permission(
        self,
        request,
        view,
    ):

        user = request.user

        if not (
            user
            and user.is_authenticated
        ):
            return False

        if request.method in SAFE_METHODS:
            return True

        if user.is_superuser:
            return True

        return user.role in getattr(
            view,
            "write_roles",
            ("admin",),
        )