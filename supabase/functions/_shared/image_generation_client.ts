// Thin abstraction over the image-generation provider. Swapping
// providers later should mean touching only this file, never
// sprite_pipeline.ts or finalize_capture.ts.
//
// Currently targets OpenAI's GPT-Image-2.5 Sunburst model via the
// /v1/images/edits endpoint (image-in, image-out — what we need for
// both "photo -> front sprite" and "front sprite -> back sprite").
// Chosen specifically for native transparent-background support
// (background: "transparent" + output_format: "png", a real alpha
// channel, no manual cutout needed) and reference-image consistency.
//
// VERIFY before deploying: check
// https://platform.openai.com/docs/models for the exact current
// model id — "sunburst"/"flare" are code names that may map to a
// slightly different API string, and OpenAI's image line-up shifts
// fast.
const OPENAI_MODEL = "gpt-image-2.5-sunburst";
const OPENAI_EDIT_URL = "https://api.openai.com/v1/images/edits";

// Modello di visione economico per il controllo di plausibilità
// (askAboutImages). VERIFICARE anche questo prima del deploy: serve
// solo un sì/no testuale su due immagini, non serve il modello più
// potente disponibile.
const OPENAI_VISION_MODEL = "gpt-4o-mini";
const OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions";

export interface ImageReference {
  bytes: Uint8Array;
  mimeType: string; // e.g. "image/jpeg", "image/png"
}

export interface GeneratedImage {
  bytes: Uint8Array;
  mimeType: string;
}

function apiKey(): string {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) {
    throw new Error(
      "OPENAI_API_KEY non configurata. Imposta con: supabase secrets set OPENAI_API_KEY=...",
    );
  }
  return key;
}

/// Genera un'immagine a partire da un prompt testuale e 1+ immagini
/// di riferimento (l'endpoint /images/edits richiede almeno
/// un'immagine in ingresso). Lancia un'eccezione in caso di
/// problema — chi chiama deve gestire il fallback (vedi
/// sprite_pipeline.ts): un intoppo della generazione non deve mai
/// far fallire una cattura.
export async function generateImage(
  prompt: string,
  references: ImageReference[],
): Promise<GeneratedImage> {
  if (references.length === 0) {
    throw new Error("generateImage richiede almeno un'immagine di riferimento.");
  }

  const form = new FormData();
  form.append("model", OPENAI_MODEL);
  form.append("prompt", prompt);
  form.append("background", "transparent");
  form.append("output_format", "png");

  for (const ref of references) {
    form.append("image[]", new Blob([ref.bytes as BlobPart], { type: ref.mimeType }), "reference.png");
  }

  const response = await fetch(OPENAI_EDIT_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey()}` },
    body: form,
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI image API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  const b64 = data?.data?.[0]?.b64_json;
  if (!b64) {
    throw new Error("OpenAI non ha restituito nessuna immagine (risposta inattesa).");
  }

  return { bytes: base64Decode(b64), mimeType: "image/png" };
}

/// Pone una domanda a risposta breve su una o più immagini (usato per
/// il controllo di plausibilità fronte/retro, vedi sprite_pipeline.ts).
/// Ritorna il testo grezzo della risposta.
export async function askAboutImages(
  question: string,
  images: ImageReference[],
): Promise<string> {
  const content: unknown[] = [{ type: "text", text: question }];
  for (const img of images) {
    content.push({
      type: "image_url",
      image_url: { url: `data:${img.mimeType};base64,${base64Encode(img.bytes)}` },
    });
  }

  const response = await fetch(OPENAI_CHAT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: OPENAI_VISION_MODEL,
      messages: [{ role: "user", content }],
      max_tokens: 5,
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI chat API error ${response.status}: ${errText}`);
  }

  const data = await response.json();
  return data?.choices?.[0]?.message?.content ?? "";
}

// Deno non ha Buffer: piccoli helper base64 fatti a mano, a chunk per
// non rischiare "Maximum call stack size exceeded" su immagini grandi.
function base64Encode(bytes: Uint8Array): string {
  const chunkSize = 8192;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function base64Decode(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}
