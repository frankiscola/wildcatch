// Determina l'animale raffigurato nella foto originale usando la
// vision dell'API Anthropic (Claude). Il risultato (es. "gatto")
// diventa species_hint/nickname della creatura, e sarà anche il
// testo da passare a Ludo.ai in modalità "Generate from References"
// per la generazione dello sprite vero e proprio.
//
// Richiede il secret ANTHROPIC_API_KEY impostato sul progetto:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// (oppure dalla dashboard: Edge Functions -> Secrets). Non gestibile
// da qui: nessuno strumento del connettore Supabase può impostare i
// secret delle function, va fatto manualmente.

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
// Modello economico e veloce: per un singolo sostantivo non serve
// altro. Se non disponibile sul tuo account, sostituiscilo con un
// altro modello Claude che hai abilitato.
const CLASSIFIER_MODEL = "claude-haiku-4-5-20251001";

function toBase64(bytes: ArrayBuffer): string {
  const uint8 = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < uint8.length; i++) {
    binary += String.fromCharCode(uint8[i]);
  }
  return btoa(binary);
}

/// Ritorna un sostantivo minuscolo in italiano (es. "gatto", "cane",
/// "gabbiano"). Fallback su "animale" se la classificazione fallisce
/// per qualunque motivo: non deve mai bloccare la cattura.
export async function classifySpecies(photoUrl: string): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.warn(
      "ANTHROPIC_API_KEY non impostata: species_hint resterà generico.",
    );
    return "animale";
  }

  try {
    const photoResponse = await fetch(photoUrl);
    if (!photoResponse.ok) {
      throw new Error(`Foto non raggiungibile: ${photoResponse.status}`);
    }
    const contentType = photoResponse.headers.get("content-type") ?? "image/jpeg";
    const bytes = await photoResponse.arrayBuffer();
    const base64 = toBase64(bytes);

    const response = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: CLASSIFIER_MODEL,
        max_tokens: 20,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: { type: "base64", media_type: contentType, data: base64 },
              },
              {
                type: "text",
                text:
                  "Rispondi con UNA sola parola, in italiano, minuscola: " +
                  "che animale è raffigurato nella foto? Se non riesci a " +
                  "identificarlo con certezza, rispondi semplicemente 'animale'.",
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error("Errore Anthropic API:", await response.text());
      return "animale";
    }

    const data = await response.json();
    const text: string = data.content?.[0]?.text ?? "animale";
    const word = text.trim().toLowerCase().replace(/[^a-zàèéìòù]/g, "");
    return word || "animale";
  } catch (e) {
    console.error("classifySpecies fallita:", e);
    return "animale";
  }
}
