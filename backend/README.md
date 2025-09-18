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

## Notes
- Si `OPENAI_API_KEY` est vide, l'API répond en mode mock déterministe (latence artificielle incluse).
- Les journaux incluent `requestId`, durée de traitement et source de réponse pour faciliter le debugging.
