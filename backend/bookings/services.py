from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from inventory.models import Materiel
from .models import Projet, Reservation, Emprunt, Notification


# ============================================================
# STATUTS ACTIFS
# ============================================================

ACTIVES = (
    Reservation.Statut.RESERVEE,
    Reservation.Statut.SORTIE,
)

EMPRUNTS_ACTIFS = (
    Emprunt.Statut.PLANIFIE,
    Emprunt.Statut.EN_COURS,
    Emprunt.Statut.EN_RETARD,
)


# ============================================================
# OUTILS
# ============================================================

def _local_date(value):
    """
    Convertit un DateTimeField en date locale Madagascar.

    Exemple :
    2026-10-15 21:00 UTC
    devient
    2026-10-16 en heure locale UTC+3.
    """
    if value is None:
        return None

    if timezone.is_aware(value):
        return timezone.localtime(value).date()

    return value.date()


def _today():
    """
    Date locale actuelle du serveur.
    """
    return timezone.localdate()


# ============================================================
# CONFLITS RESERVATION
# ============================================================

def find_conflicts(materiel, date_sortie, date_retour, exclude_id=None):
    """
    Vérifie si le matériel possède déjà une réservation
    active sur la période demandée.
    """

    qs = Reservation.objects.filter(
        materiel=materiel,
        statut__in=ACTIVES,
        date_sortie_prevue__lt=date_retour,
        date_retour_prevue__gt=date_sortie,
    )

    if exclude_id:
        qs = qs.exclude(pk=exclude_id)

    return qs.exists()


def find_emprunt_conflicts(
    materiel,
    date_depart,
    date_retour,
    exclude_id=None,
):
    """
    Vérifie si le matériel est déjà concerné par un emprunt actif.
    """

    qs = Emprunt.objects.filter(
        materiel=materiel,
        statut__in=EMPRUNTS_ACTIFS,
        date_depart_prevue__lt=date_retour,
        date_retour_prevue__gt=date_depart,
    )

    if exclude_id:
        qs = qs.exclude(pk=exclude_id)

    return qs.exists()


# ============================================================
# STATUT MATERIEL
# ============================================================

def _set_material_status(materiel, status):
    """
    Modifie le statut du matériel uniquement si nécessaire.
    """

    if materiel.statut == status:
        return

    materiel.statut = status
    materiel.save(update_fields=["statut"])


def _restore_material_status(materiel):
    """
    Détermine automatiquement le statut courant d'un matériel.

    Priorité :

    1. Hors service
    2. Maintenance
    3. Emprunt actif
    4. Projet en cours
    5. Disponible
    """

    # --------------------------------------------------------
    # 1. Hors service
    # --------------------------------------------------------

    if materiel.statut == Materiel.Statut.HORS_SERVICE:
        return

    # --------------------------------------------------------
    # 2. Maintenance
    # --------------------------------------------------------

    if materiel.statut == Materiel.Statut.MAINTENANCE:
        return

    # --------------------------------------------------------
    # 3. Emprunt actif
    # --------------------------------------------------------

    emprunt_actif = Emprunt.objects.filter(
        materiel=materiel,
        statut__in=EMPRUNTS_ACTIFS,
    ).exists()

    if emprunt_actif:
        _set_material_status(
            materiel,
            Materiel.Statut.EMPRUNTE,
        )
        return

    # --------------------------------------------------------
    # 4. Projet actuellement EN COURS
    # --------------------------------------------------------

    tournage_projet = Reservation.objects.filter(
        materiel=materiel,
        statut__in=ACTIVES,
        projet__statut=Projet.Statut.EN_COURS,
    ).exists()

    if tournage_projet:
        _set_material_status(
            materiel,
            Materiel.Statut.TOURNAGE,
        )
        return

    # --------------------------------------------------------
    # 5. Sinon disponible
    # --------------------------------------------------------

    _set_material_status(
        materiel,
        Materiel.Statut.DISPO,
    )


# ============================================================
# SYNCHRONISATION DES PROJETS
# ============================================================

def update_project_statuses():
    """
    Met automatiquement à jour le statut des projets
    selon la DATE locale uniquement.

    Règle :

    date actuelle < date début
        -> PREPARATION

    date début <= date actuelle <= date fin
        -> EN_COURS

    date actuelle > date fin
        -> TERMINE

    Le statut ANNULE n'est jamais écrasé.
    """

    today = _today()

    projets = Projet.objects.all()

    for projet in projets:

        # ----------------------------------------------------
        # Projet annulé : on ne touche pas au statut
        # ----------------------------------------------------

        if projet.statut == Projet.Statut.ANNULE:
            continue

        debut = _local_date(projet.date_debut)
        fin = _local_date(projet.date_fin)

        if debut is None or fin is None:
            continue

        # ----------------------------------------------------
        # Avant le début
        # ----------------------------------------------------

        if today < debut:
            nouveau_statut = Projet.Statut.PREPARATION

        # ----------------------------------------------------
        # Pendant la période
        # ----------------------------------------------------

        elif debut <= today <= fin:
            nouveau_statut = Projet.Statut.EN_COURS

        # ----------------------------------------------------
        # Après la fin
        # ----------------------------------------------------

        else:
            nouveau_statut = Projet.Statut.TERMINE

        if projet.statut != nouveau_statut:
            projet.statut = nouveau_statut
            projet.save(update_fields=["statut"])


# ============================================================
# SYNCHRONISATION GENERALE
# ============================================================

def update_material_status():
    """
    Fonction principale appelée par l'API.

    Elle fait dans l'ordre :

    1. Mise à jour automatique des projets
    2. Mise à jour automatique des matériels
    """

    # --------------------------------------------------------
    # ETAPE 1 : synchroniser les projets
    # --------------------------------------------------------

    update_project_statuses()

    # --------------------------------------------------------
    # ETAPE 2 : synchroniser les matériels
    # --------------------------------------------------------

    for materiel in Materiel.objects.all():

        # Les accessoires d'un parent ne sont pas traités
        # comme des unités opérationnelles autonomes.
        if materiel.kit_parent_id is not None:
            continue

        _restore_material_status(materiel)


# ============================================================
# SORTIE D'UN MATERIEL
# ============================================================

@transaction.atomic
def check_out(reservation):
    """
    Valide la sortie d'un matériel pour une réservation.
    """

    reservation.statut = Reservation.Statut.SORTIE
    reservation.date_sortie_reelle = timezone.now()

    reservation.save(
        update_fields=[
            "statut",
            "date_sortie_reelle",
        ]
    )

    materiel = reservation.materiel

    _set_material_status(
        materiel,
        Materiel.Statut.TOURNAGE,
    )

    # --------------------------------------------------------
    # Le projet passe automatiquement en cours
    # --------------------------------------------------------

    projet = reservation.projet

    if projet.statut == Projet.Statut.PREPARATION:
        projet.statut = Projet.Statut.EN_COURS
        projet.save(update_fields=["statut"])

    return reservation


# ============================================================
# RETOUR D'UN MATERIEL
# ============================================================

@transaction.atomic
def check_in(reservation):
    """
    Enregistre le retour d'un matériel.
    """

    reservation.statut = Reservation.Statut.RETOURNEE
    reservation.date_retour_reelle = timezone.now()

    reservation.save(
        update_fields=[
            "statut",
            "date_retour_reelle",
        ]
    )

    materiel = reservation.materiel

    _restore_material_status(materiel)

    # --------------------------------------------------------
    # Si aucun matériel n'est encore actif sur le projet,
    # on peut terminer le projet si sa période est terminée.
    # --------------------------------------------------------

    projet = reservation.projet

    today = _today()
    fin = _local_date(projet.date_fin)

    if (
        projet.statut == Projet.Statut.EN_COURS
        and fin is not None
        and today > fin
    ):
        projet.statut = Projet.Statut.TERMINE
        projet.save(update_fields=["statut"])

    return reservation


# ============================================================
# EMPRUNT
# ============================================================

@transaction.atomic
def start_emprunt(emprunt):
    """
    Démarre un emprunt.
    """

    emprunt.statut = Emprunt.Statut.EN_COURS
    emprunt.date_depart_reelle = timezone.now()

    emprunt.save(
        update_fields=[
            "statut",
            "date_depart_reelle",
        ]
    )

    _set_material_status(
        emprunt.materiel,
        Materiel.Statut.EMPRUNTE,
    )

    return emprunt


# ============================================================
# RETOUR EMPRUNT
# ============================================================

@transaction.atomic
def return_emprunt(emprunt):
    """
    Enregistre le retour d'un emprunt.
    """

    emprunt.statut = Emprunt.Statut.RETOURNE
    emprunt.date_retour_reelle = timezone.now()

    emprunt.save(
        update_fields=[
            "statut",
            "date_retour_reelle",
        ]
    )

    _restore_material_status(
        emprunt.materiel
    )

    return emprunt


# ============================================================
# ANNULATION EMPRUNT
# ============================================================

@transaction.atomic
def cancel_emprunt(emprunt):
    """
    Annule un emprunt.
    """

    emprunt.statut = Emprunt.Statut.ANNULE

    emprunt.save(
        update_fields=["statut"]
    )

    _restore_material_status(
        emprunt.materiel
    )

    return emprunt


# ============================================================
# NOTIFICATION RETARD
# ============================================================

def create_late_notification(emprunt):
    """
    Crée une notification lorsqu'un emprunt est en retard.

    Evite de créer plusieurs notifications identiques.
    """

    if not emprunt.utilisateur:
        return None

    cle = f"emprunt-retard-{emprunt.id}"

    notification, created = Notification.objects.get_or_create(
        utilisateur=emprunt.utilisateur,
        cle=cle,
        defaults={
            "titre": "Emprunt en retard",
            "message": (
                f"L'emprunt du matériel "
                f"{emprunt.materiel.nom} "
                f"est en retard."
            ),
        },
    )

    return notification


# ============================================================
# MISE A JOUR AUTOMATIQUE DES RESERVATIONS / EMPRUNTS
# ============================================================

def update_reservations_and_emprunts():
    """
    Vérifie les réservations et emprunts dont la date est arrivée.

    Cette fonction peut être appelée périodiquement ou avant
    l'affichage des données.
    """

    now = timezone.now()

    # --------------------------------------------------------
    # Réservations réservées dont la sortie est arrivée
    # --------------------------------------------------------

    reservations = Reservation.objects.filter(
        statut=Reservation.Statut.RESERVEE,
        date_sortie_prevue__lte=now,
        date_retour_prevue__gte=now,
    )

    for reservation in reservations:

        # Le matériel passe en tournage.
        _set_material_status(
            reservation.materiel,
            Materiel.Statut.TOURNAGE,
        )

    # --------------------------------------------------------
    # Emprunts planifiés dont le départ est arrivé
    # --------------------------------------------------------

    emprunts = Emprunt.objects.filter(
        statut=Emprunt.Statut.PLANIFIE,
        date_depart_prevue__lte=now,
    )

    for emprunt in emprunts:
        start_emprunt(emprunt)

    # --------------------------------------------------------
    # Emprunts en cours arrivés à échéance
    # --------------------------------------------------------

    en_retard = Emprunt.objects.filter(
        statut=Emprunt.Statut.EN_COURS,
        date_retour_prevue__lt=now,
    )

    for emprunt in en_retard:

        if emprunt.statut != Emprunt.Statut.EN_RETARD:
            emprunt.statut = Emprunt.Statut.EN_RETARD
            emprunt.save(
                update_fields=["statut"]
            )

        create_late_notification(emprunt)


# ============================================================
# SYNCHRONISATION COMPLETE
# ============================================================

def synchronize_all():
    """
    Synchronisation complète du système.

    1. Projets
    2. Réservations / emprunts
    3. Matériels
    """

    update_project_statuses()

    update_reservations_and_emprunts()

    update_material_status()