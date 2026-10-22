# Gestion de matériel de tournage

```
D:\Gestion de materiel
├── backend   Django + DRF + PostgreSQL
└── mobile    Flutter (Android APK + Web)
```

## 1. Backend
```bat
cd "D:\Gestion de materiel\backend"
.\venv\Scripts\Activate.ps1
docker compose up -d
$env:ALLOWED_HOSTS="localhost,127.0.0.1,192.168.43.122"
python manage.py runserver 0.0.0.0:8000
```
API : http://localhost:8000/api/  •  Admin Django : http://localhost:8000/admin/
Rappels/retards (à planifier toutes les heures) : `python manage.py send_reminders`

## 2. Mobile
```bat
cd mobile
flutter create . --platforms=android,web --org com.exemple   :: génère android/ et web/ (ne touche pas lib/)
flutter pub get
flutter run -d chrome                                         :: Web
flutter run                                                   :: Android (émulateur : API = 10.0.2.2:8000)
flutter build apk --release --dart-define=API_URL=http://IP_DU_PC:8000/api
```
Sur téléphone réel, utilisez l'IP LAN du PC (`--dart-define=API_URL=...`).

### Android : android/app/src/main/AndroidManifest.xml
Dans `<manifest>` :
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```
Dans `<application ...>` (HTTP en développement) : `android:usesCleartextTraffic="true"`
