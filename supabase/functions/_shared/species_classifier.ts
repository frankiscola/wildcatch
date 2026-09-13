// Determines the animal shown in the original photo using the
// Anthropic API's (Claude's) vision. The result (e.g. "cat") becomes
// the Wildkin's species_hint/nickname base, and will also be the
// text passed to Ludo.ai in "Generate from References" mode for the
// actual sprite generation.
//
// Requires the ANTHROPIC_API_KEY secret set on the project:
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
// (or from the dashboard: Edge Functions -> Secrets). Can't be
// managed from here: no tool in the Supabase connector can set
// function secrets, it has to be done manually.

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
// Cheap and fast model: nothing more is needed for a single noun. If
// it's not available on your account, swap in another Claude model
// you have enabled.
const CLASSIFIER_MODEL = "claude-haiku-4-5-20251001";

function toBase64(bytes: ArrayBuffer): string {
  const uint8 = new Uint8Array(bytes);
  let binary = "";
  for (let i = 0; i < uint8.length; i++) {
    binary += String.fromCharCode(uint8[i]);
  }
  return btoa(binary);
}

/// Returns a lowercase English noun (e.g. "cat", "dog", "seagull").
/// Falls back to "animal" if classification fails for any reason: it
/// must never block the capture.
export async function classifySpecies(photoUrl: string): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.warn(
      "ANTHROPIC_API_KEY not set: species_hint will stay generic.",
    );
    return "animal";
  }

  try {
    const photoResponse = await fetch(photoUrl);
    if (!photoResponse.ok) {
      throw new Error(`Photo unreachable: ${photoResponse.status}`);
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
                  "Answer with ONE word only, in English, lowercase: " +
                  "what animal is shown in the photo? If you can't identify " +
                  "it with confidence, just answer 'animal'.",
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      console.error("Anthropic API error:", await response.text());
      return "animal";
    }

    const data = await response.json();
    const text: string = data.content?.[0]?.text ?? "animal";
    const word = text.trim().toLowerCase().replace(/[^a-z]/g, "");
    return word || "animal";
  } catch (e) {
    console.error("classifySpecies failed:", e);
    return "animal";
  }
}
