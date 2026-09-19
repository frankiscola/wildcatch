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

// Cheap vision model for the plausibility check (askAboutImages).
// Also VERIFY this before deploying: it only needs a plain yes/no on
// two images, no need for the most powerful model available.
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
      "OPENAI_API_KEY not set. Configure it with: supabase secrets set OPENAI_API_KEY=...",
    );
  }
  return key;
}

/// Generates an image from a text prompt and 1+ reference images
/// (the /images/edits endpoint requires at least one input image).
/// Throws on any problem — the caller is responsible for the
/// fallback (see sprite_pipeline.ts): a generation hiccup should
/// never fail a capture.
export async function generateImage(
  prompt: string,
  references: ImageReference[],
): Promise<GeneratedImage> {
  if (references.length === 0) {
    throw new Error("generateImage requires at least one reference image.");
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
    throw new Error("OpenAI did not return any image (unexpected response).");
  }

  return { bytes: base64Decode(b64), mimeType: "image/png" };
}

/// Asks a short-answer question about one or more images (used for
/// the front/back plausibility check, see sprite_pipeline.ts).
/// Returns the raw response text.
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

// Deno has no Buffer: small hand-rolled base64 helpers, chunked to
// avoid "Maximum call stack size exceeded" on large images.
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
