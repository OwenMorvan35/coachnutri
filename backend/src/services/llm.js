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
    'Tu es CoachNutri, coach nutrition bienveillant francophone.',
    'Appuie-toi sur les repères OMS/ANSES et vulgarise sans culpabiliser.',
    'Réponds en 3 blocs distincts :',
    '⚡ Diagnostic : synthèse courte en une phrase.',
    '✅ 3 actions : liste numérotée de trois actions concrètes.',
    '💡 Tip : une astuce bonus pratique.',
    formatProfileContext(profile),
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
  const timeout = setTimeout(() => controller.abort(), 25_000);

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
      const timeoutErr = new Error('OpenAI API timeout après 25s');
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
