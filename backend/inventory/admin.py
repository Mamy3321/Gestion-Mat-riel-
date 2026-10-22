from django.contrib import admin
from .models import Categorie, Maintenance, Materiel

admin.site.register(Categorie)
admin.site.register(Maintenance)


@admin.register(Materiel)
class MaterielAdmin(admin.ModelAdmin):
    list_display = ("nom", "categorie", "statut", "etat", "qr_code")
    list_filter = ("categorie", "statut", "etat")
    search_fields = ("nom", "numero_serie", "qr_code")
