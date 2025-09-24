import fetch from 'node-fetch';
import { logError } from '../logger.js';

const formatProfileContext = (profile = {}) => {
  const details = [];
  if (profile.objective) {
    details.push(`Objectif: ${profile.objective}`);
  }
  if (typeof profile.age === 'number') {
    details.push(`Age: ${profile.age} ans`);
  }
  if (typeof profile.heightCm === 'number') {
    details.push(`Taille: ${profile.heightCm} cm`);
  }
  if (typeof profile.weightKg === 'number') {
    details.push(`Poids: ${profile.weightKg} kg`);
  }
  if (Array.isArray(profile.prefs) && profile.prefs.length > 0) {
    details.push(`Préférences: ${profile.prefs.join(', ')}`);
  }

  return details.length > 0 ? `Profil client: ${details.join(' | ')}.` : 'Profil client: non renseigné.';
};

export const buildSystemPrompt = (profile) => {
  return [
    'Tu es NutrIA, un coach en nutrition virtuel, expert et bienveillant.',
    'Ton rôle est d\'aider les utilisateurs à mieux comprendre leur alimentation, à améliorer leurs habitudes et à atteindre leurs objectifs (santé, énergie, poids, sport) de manière claire, personnalisée et motivante.',
    '',
    '🎯 Lignes directrices :',
    '- Tu es professionnel : tes réponses sont basées sur des connaissances fiables (ANSES, CIQUAL, OMS, sources reconnues en nutrition).',
    '- Tu es humain et empathique : réponds comme un coach à l\'écoute, qui s\'adapte à la personne et prend en compte ses émotions, ses contraintes et son contexte de vie.',
    '- Tu es clair et pédagogique : vulgarise les termes techniques, donne des exemples concrets, propose des astuces faciles à appliquer.',
    '- Tu es positif et motivant : félicite les efforts, encourage la progression, jamais de jugement.',
    '- Tu as une petite touche d\'humour légère pour rendre la discussion agréable (ex. une blague subtile, une comparaison marrante avec la nourriture), sans jamais ridiculiser l\'utilisateur.',
    '',
    '⚠️ Limites :',
    '- Tu n\'es pas un médecin : tu ne poses pas de diagnostic médical, tu ne prescris pas de traitement.',
    '- Si la question dépasse ton champ (maladies chroniques, troubles graves), conseille gentiment de consulter un professionnel de santé.',
    '- Tu donnes uniquement des informations nutritionnelles générales et des conseils d\'hygiène de vie, jamais de promesses irréalistes.',
    '',
    '🛠️ Style de réponse :',
    '1. Accueille la question de manière chaleureuse et montre que tu as compris la demande.',
    '2. Donne une réponse claire et structurée (explication + astuces/action concrète).',
    '3. Ajoute une touche humaine (encouragement, mini-blague, métaphore culinaire).',
    '4. Termine en ouvrant la conversation (ex : « Est-ce que tu veux que je te propose un exemple de repas adapté à ça ? »).',
    '',
    'Exemple de ton attendu :',
    'Utilisateur : *« Je grignote trop le soir, je fais quoi ? »*',
    'NutrIA : *« Ah, le fameux \u2018frigo qui appelle à minuit\u2019, tu n\'es pas seul·e dans ce combat 😅. Souvent, c\'est lié à l\'habitude plus qu\'à la faim réelle. Ce qui marche bien : préparer une tisane ou une collation saine à l\'avance, histoire de détourner ton cerveau. Tu veux que je te donne 2-3 idées de snacks malins qui coupent l\'envie sans plomber ton sommeil ? »*',
    '',
    'Ton objectif final : être perçu comme un coach nutrition sympa, compétent et disponible, qui rend l\'info claire, utile, et agréable à lire.',
    '',
    // Contexte dynamique utilisateur
    formatProfileContext(profile),
    '',
    // Instructions d\'intégration app (actions optionnelles)
    'Si une action concrète doit être exécutée par l\'app, ajoute en fin de réponse une section optionnelle "ACTIONS:" contenant UNIQUEMENT un JSON valide (sans texte autour).',
    'Types autorisés :',
    '- recipe_batch: {"type":"recipe_batch","recipes":[{"id":"rec_abc123","title":"...","image":"https://...","readyInMin":25,"servings":2,"tags":["..."],"ingredients":[{"name":"...","qty":300,"unit":"g","category":"..."}],"steps":["..."],"nutrition":{"kcal":420,"protein_g":38,"carb_g":12,"fat_g":24}}]}',
    '- shopping_list_update: {"type":"shopping_list_update","listId":"default","items":[{"name":"...","qty":300,"unit":"g","category":"...","note":"...","op":"add|remove|toggle"}]}',
    'Ne crée pas la section ACTIONS s\'il n\'y a aucune action concrète.',
  ].join('\n');
};

const normalizeHistory = (history = []) => {
  if (!Array.isArray(history)) {
    return [];
  }

  return history
    .filter((item) => item && typeof item.content === 'string' && item.content.trim().length > 0)
    .map((item) => {
      const content = item.content.trim();
      switch (item.role) {
        case 'coach':
          return { role: 'assistant', content };
        case 'user':
          return { role: 'user', content };
        case 'system':
        case 'assistant':
          return { role: item.role, content };
        default:
          return { role: 'user', content };
      }
    });
};

const buildMessages = ({ message, history = [], profile }) => {
  const systemContent = buildSystemPrompt(profile);
  const normalizedHistory = normalizeHistory(history);
  return [
    { role: 'system', content: systemContent },
    ...normalizedHistory,
    { role: 'user', content: message },
  ];
};

export const callOpenAI = async ({ message, history, profile, model, apiKey }) => {
  if (!apiKey) {
    throw new Error('OpenAI API key is required');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 35_000);

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: buildMessages({ message, history, profile }),
      }),
      signal: controller.signal,
    });

    clearTimeout(timeout);

    if (!response.ok) {
      const errorBody = await response.text();
      const err = new Error(`OpenAI API error (${response.status})`);
      err.status = response.status;
      err.details = errorBody;
      throw err;
    }

    const payload = await response.json();
    const choice = payload.choices?.[0];
    const reply = choice?.message?.content?.trim();

    if (!reply) {
      throw new Error('Réponse OpenAI invalide : contenu vide');
    }

    return {
      reply,
      model: payload.model || model,
      tokens: payload.usage?.total_tokens ?? null,
      from: 'openai',
    };
  } catch (error) {
    if (error.name === 'AbortError') {
      const timeoutErr = new Error('OpenAI API timeout après 35s');
      timeoutErr.code = 'openai_timeout';
      throw timeoutErr;
    }
    logError('callOpenAI', 'Erreur lors de la requête OpenAI', error);
    throw error;
  } finally {
    clearTimeout(timeout);
  }
};

const buildMockContent = ({ message, profile }) => {
  const lower = message.toLowerCase();
  const objective = profile?.objective || 'équilibre alimentaire';
  const prefs = Array.isArray(profile?.prefs) && profile.prefs.length > 0 ? ` en respectant tes préférences (${profile.prefs.join(', ')})` : '';

  if (lower.includes('/repas')) {
    return {
      diagnostic: "Plan repas demandé : on mise sur un apport équilibré dans la journée.",
      actions: [
        'Petit-déjeuner : yaourt nature + flocons d\'avoine + fruit frais',
        'Déjeuner : bol de quinoa, légumes rôtis, légumineuses et filet de citron',
        'Dîner : soupe de légumes + tartine de pain complet avec protéine maigre',
      ],
      tip: 'Prépare les légumes à l\'avance pour gagner du temps sur la semaine.',
    };
  }

  if (lower.includes('/courses')) {
    return {
      diagnostic: "Liste de courses simple pour rester aligné(e) avec ton objectif.",
      actions: [
        'Fruits & légumes de saison (au moins 5 variétés)',
        'Protéines maigres (poisson, tofu, légumineuses) + céréales complètes',
        'Oléagineux nature et huiles riches en oméga-3',
      ],
      tip: 'Fais les courses après avoir mangé pour éviter les achats impulsifs.',
    };
  }

  if (lower.includes('/astuce')) {
    return {
      diagnostic: "Tu veux une astuce rapide pour mieux t\'organiser.",
      actions: [
        'Fixe un créneau meal prep court 2 fois par semaine',
        'Garde une base de légumes crus prêts à consommer',
        'Prépare une gourde d\'eau aromatisée dès le matin',
      ],
      tip: 'Utilise un rappel sur ton téléphone pour boire toutes les 2 heures.',
    };
  }

  return {
    diagnostic: `On vise ${objective}${prefs} : garde un rythme régulier et hydrate-toi bien.`,
    actions: [
      'Structure tes repas autour de légumes, protéines maigres et féculents complets',
      'Bouge au moins 30 minutes aujourd\'hui pour soutenir ton métabolisme',
      'Planifie ton prochain repas en avance pour éviter les grignotages',
    ],
    tip: 'Ajoute une portion de légumes ou fruits supplémentaires dans ton prochain repas.',
  };
};

export const mockReply = async ({ message, profile }) => {
  const start = Date.now();
  const content = buildMockContent({ message, profile });

  await new Promise((resolve) => setTimeout(resolve, 500));

  return {
    reply: [
      `⚡ Diagnostic : ${content.diagnostic}`,
      `\n✅ 3 actions :\n1. ${content.actions[0]}\n2. ${content.actions[1]}\n3. ${content.actions[2]}`,
      `\n💡 Tip : ${content.tip}`,
    ].join('\n'),
    model: 'mock-coachnutri',
    tokens: null,
    from: 'mock',
    duration: Date.now() - start,
  };
};
