# CoachNutri Backend

Serveur Express sécurisé et prêt pour la production, dédié aux fonctionnalités CoachNutri.

## Prérequis
- Node.js \>= 18
- npm 9+

## Installation
```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

## Variables d'environnement
- `PORT` : port HTTP d'écoute (par défaut 5001)
- `OPENAI_API_KEY` : clé API OpenAI (laisser vide pour mode mock) 
- `OPENAI_MODEL` : modèle utilisé pour les complétions
- `CORS_ORIGINS` : origines autorisées séparées par des virgules
- `RATE_LIMIT_WINDOW_MS` / `RATE_LIMIT_MAX` : configuration du rate limit sur `/coach`

## Tests rapides
```bash
curl -s http://localhost:5001/healthz | jq
curl -s -X POST http://localhost:5001/coach \
  -H "Content-Type: application/json" \
  -d '{ "message":"Jai mangé un kebab hier", "profile":{"objective":"mieux manger"}, "history":[{"role":"user","content":"salut"}] }' | jq
```

## Suivi de poids

Nouvelles routes sécurisées (token Bearer requis) :

```bash
# Récupérer les mesures sur la semaine courante (agrégation par dernière valeur du jour)
curl -s "http://localhost:5001/weights?range=week" \
  -H "Authorization: Bearer <token>" | jq

# Ajouter une mesure manuelle (UTC)
curl -s -X POST http://localhost:5001/weights \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"weightKg":82.4,"date":"2025-09-12T07:30:00.000Z","note":"après footing"}' | jq

# Parser une phrase en français et enregistrer automatiquement
curl -s -X POST http://localhost:5001/nlp/weights/parse-and-log \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"text":"enregistre 83,2 kg hier soir"}' | jq
```

Phrases reconnues côté coach (exemples) :
- « Enregistre 82,4 kg le 12/09 »
- « Note 83 kg hier »
- « Ajoute 79,8 kg le 5 septembre »

Contraintes : poids entre 20 et 400 kg, dates futures refusées, stockage UTC.

## Profil utilisateur

Gestion de l'identité (token Bearer requis) :

```bash
# Profil courant
curl -s http://localhost:5001/users/me \
  -H "Authorization: Bearer <token>" | jq

# Mettre à jour le pseudo / nom
curl -s -X PUT http://localhost:5001/users/me \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"displayName":"Alex Coach","name":"Alex Martin"}' | jq

# Modifier le mot de passe
curl -s -X POST http://localhost:5001/users/me/password \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"currentPassword":"ancien123","newPassword":"nouveau123"}' -i

# Téléverser un avatar
curl -s -X POST http://localhost:5001/users/me/avatar \
  -H "Authorization: Bearer <token>" \
  -F "avatar=@/chemin/vers/avatar.png"

# Profil santé / nutrition
curl -s http://localhost:5001/users/me/nutrition \
  -H "Authorization: Bearer <token>" | jq

curl -s -X PUT http://localhost:5001/users/me/nutrition \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
        "gender": "FEMALE",
        "goal": "LOSE",
        "activityLevel": "MODERATE",
        "heightCm": 168,
        "startingWeightKg": 72.5,
        "allergies": ["arachides"],
        "dietaryPreferences": ["vegan"],
        "constraints": ["budget limité"],
        "medicalConditions": "Hypothyroïdie"
      }' | jq
```

## Notes
- Si `OPENAI_API_KEY` est vide, l'API répond en mode mock déterministe (latence artificielle incluse).
- Les journaux incluent `requestId`, durée de traitement et source de réponse pour faciliter le debugging.
