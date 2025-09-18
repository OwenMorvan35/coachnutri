# CoachNutri

CoachNutri est une application Flutter accompagnée d'un backend Node.js/Express pour faciliter le coaching nutritionnel personnalisé.

## Dossiers principaux
- `lib/` : application Flutter (UI, services clients).
- `backend/` : API Express sécurisée (routes coach, auth, recettes, listes de courses).
- `prisma/` : schémas et migrations Prisma pour la base PostgreSQL.

## Démarrage rapide
```bash
# Frontend
flutter pub get
flutter run

# Backend
cd backend
npm install
npm run dev
```

Consulte `backend/README.md` pour plus de détails côté serveur.
