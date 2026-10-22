from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import (
    TokenRefreshView,
)


# ============================================================
# ACCOUNTS
# ============================================================

from accounts.views import (
    LoginView,
    MeView,
    RegisterView,
    ProfileView,
    ApproveUserView,
    RejectUserView,
    UserViewSet,
)


# ============================================================
# BOOKINGS
# ============================================================

from bookings.views import (
    DashboardView,
    NotificationViewSet,
    ProjetViewSet,
    ReservationViewSet,
    EmpruntViewSet,
)


# ============================================================
# INVENTORY
# ============================================================

from inventory.views import (
    CategorieViewSet,
    MaintenanceViewSet,
    MaterielViewSet,
)


# ============================================================
# ROUTER
# ============================================================

router = DefaultRouter()


# ------------------------------------------------------------
# USERS
# ------------------------------------------------------------

router.register(
    "users",
    UserViewSet,
    basename="user",
)


# ------------------------------------------------------------
# INVENTORY
# ------------------------------------------------------------

router.register(
    "categories",
    CategorieViewSet,
)

router.register(
    "materiels",
    MaterielViewSet,
)

router.register(
    "maintenances",
    MaintenanceViewSet,
)


# ------------------------------------------------------------
# PROJECTS
# ------------------------------------------------------------

router.register(
    "projets",
    ProjetViewSet,
)


# ------------------------------------------------------------
# RESERVATIONS
# ------------------------------------------------------------

router.register(
    "reservations",
    ReservationViewSet,
)


# ------------------------------------------------------------
# EMPRUNTS
# ------------------------------------------------------------

router.register(
    "emprunts",
    EmpruntViewSet,
    basename="emprunt",
)


# ------------------------------------------------------------
# NOTIFICATIONS
# ------------------------------------------------------------

router.register(
    "notifications",
    NotificationViewSet,
    basename="notification",
)


# ============================================================
# URLS
# ============================================================

urlpatterns = [

    # ========================================================
    # DJANGO ADMIN
    # ========================================================

    path(
        "admin/",
        admin.site.urls,
    ),

    # ========================================================
    # LOGIN
    # ========================================================

    path(
        "api/auth/login/",
        LoginView.as_view(),
        name="login",
    ),

    # ========================================================
    # TOKEN REFRESH
    # ========================================================

    path(
        "api/auth/refresh/",
        TokenRefreshView.as_view(),
        name="token-refresh",
    ),

    # ========================================================
    # UTILISATEUR CONNECTÉ
    # ========================================================

    path(
        "api/auth/me/",
        MeView.as_view(),
        name="me",
    ),

    # ========================================================
    # REGISTER
    # ========================================================

    path(
        "api/auth/register/",
        RegisterView.as_view(),
        name="register",
    ),

    # ========================================================
    # PROFILE
    # ========================================================

    path(
        "api/auth/profile/",
        ProfileView.as_view(),
        name="profile",
    ),

    # ========================================================
    # APPROUVER UTILISATEUR
    # ========================================================

    path(
        "api/users/<int:pk>/approve/",
        ApproveUserView.as_view(),
        name="approve-user",
    ),

    # ========================================================
    # REFUSER UTILISATEUR
    # ========================================================

    path(
        "api/users/<int:pk>/reject/",
        RejectUserView.as_view(),
        name="reject-user",
    ),

    # ========================================================
    # DASHBOARD
    # ========================================================

    path(
        "api/dashboard/",
        DashboardView.as_view(),
        name="dashboard",
    ),

    # ========================================================
    # API ROUTER
    # ========================================================

    path(
        "api/",
        include(router.urls),
    ),
]


# ============================================================
# MEDIA
# ============================================================

urlpatterns += static(
    settings.MEDIA_URL,
    document_root=settings.MEDIA_ROOT,
)