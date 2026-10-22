from django.contrib import admin
from .models import Notification, Projet, Reservation, Emprunt


admin.site.register(Projet)
admin.site.register(Reservation)
admin.site.register(Notification)


@admin.register(Emprunt)
class EmpruntAdmin(admin.ModelAdmin):
    list_display = (
        "materiel",
        "utilisateur",
        "motif",
        "date_depart_prevue",
        "date_retour_prevue",
        "statut",
        "created",
    )

    list_filter = ("statut",)

    search_fields = (
        "materiel__nom",
        "materiel__qr_code",
        "utilisateur__username",
        "motif",
    )

    ordering = ("-date_depart_prevue",)