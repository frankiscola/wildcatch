// Orchestrazione della generazione sprite: fronte dalla foto reale,
// poi retro incatenato dal fronte (non dalla foto originale, per
// coerenza visiva — vedi la discussione nel progetto), con un
// controllo di plausibilità automatico e un solo retry se il retro
// non sembra la stessa creatura del fronte.
//
// NESSUNA garanzia assoluta: nessun modello attuale ricostruisce
// davvero la creatura in 3D per "girare la telecamera", sta
// indovinando in modo plausibile. Questo file riduce il tasso di
// errori evidenti, non lo azzera — vedi anche il pulsante "rigenera"
// lato UI per l'ultima rete di sicurezza (da aggiungere lato Flutter).

import { askAboutImages, generateImage, type ImageReference } from "./image_generation_client.ts";
import { resizeToSpriteSize } from "./sprite_postprocess.ts";

const SPRITE_SIZE = 128; // vedi sprite_postprocess.ts per il perché

const STYLE_PROMPT =
  "Reinterpreta il soggetto come una creatura da collezione in stile " +
  "videogioco retrò (proporzioni chibi, contorni neri spessi, colori " +
  "piatti, illuminazione morbida, sfondo singolo colore neutro), " +
  "design originale, non ricalcato su alcun personaggio esistente. " +
  "Inquadratura a figura intera.";

const BACK_PROMPT =
  "Stessa identica creatura dell'immagine allegata: stessa palette di " +
  "colori, stessa posa eretta, stessi accessori/pattern. Mostrala però " +
  "vista ESATTAMENTE da dietro (non di 3/4): testa non visibile o solo " +
  "di profilo, arti nella posizione speculare rispetto al fronte. " +
  "Versione leggermente più semplice e meno dettagliata del fronte, " +
  "come è tipico degli sprite posteriori in questo genere di gioco.";

export interface SpriteResult {
  front: ImageReference;
  back: ImageReference;
}

export async function generateSprites(
  photo: ImageReference,
  speciesHint: string | null,
): Promise<SpriteResult> {
  const speciesNote = speciesHint ? `Il soggetto è un animale di tipo "${speciesHint}". ` : "";

  const front = await generateImage(
    `${speciesNote}${STYLE_PROMPT} Vista frontale, il soggetto guarda verso la camera.`,
    [photo],
  );

  let back = await generateImage(BACK_PROMPT, [front]);

  const plausible = await backLooksLikeSameCreature(front, back);
  if (!plausible) {
    // La generazione non è deterministica: un secondo tentativo con
    // lo stesso identico prompt spesso basta a correggere il tiro.
    back = await generateImage(BACK_PROMPT, [front]);
  }

  // Ridimensionamento SOLO alla fine: il controllo di plausibilità
  // sopra lavora sulle immagini a piena risoluzione, dove il modello
  // di visione ha più dettaglio su cui giudicare.
  const [frontSprite, backSprite] = await Promise.all([
    resizeToSpriteSize(front.bytes, SPRITE_SIZE),
    resizeToSpriteSize(back.bytes, SPRITE_SIZE),
  ]);

  return {
    front: { bytes: frontSprite, mimeType: "image/png" },
    back: { bytes: backSprite, mimeType: "image/png" },
  };
}

/// Controllo di plausibilità economico: chiede al modello stesso se
/// le due immagini sembrano la stessa creatura vista da davanti e da
/// dietro. Fallisce "aperto" (true) in caso di risposta ambigua o
/// errore di rete: meglio mostrare uno sprite imperfetto che bloccare
/// la cattura per un problema del controllo stesso.
async function backLooksLikeSameCreature(
  front: ImageReference,
  back: ImageReference,
): Promise<boolean> {
  try {
    const answer = await askAboutImages(
      "La prima immagine è il fronte di una creatura, la seconda dovrebbe " +
        "essere la stessa creatura vista da dietro. Hanno chiaramente la " +
        "stessa palette di colori, la stessa forma generale e la stessa " +
        "posa? Rispondi con una sola parola: SI oppure NO.",
      [front, back],
    );
    const normalized = answer.trim().toUpperCase();
    return !normalized.startsWith("NO");
  } catch (e) {
    console.error("Controllo plausibilità fronte/retro fallito, si procede comunque:", e);
    return true;
  }
}
