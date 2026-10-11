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

/// Error coming back from the image provider, with the HTTP status
/// and the provider's own error code kept as fields so callers can
/// react to specific cases (e.g. "moderation_blocked") without
/// string-matching the message.
export class ImageProviderError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code: string | null,
  ) {
    super(message);
    this.name = "ImageProviderError";
  }
}

// Output-stage moderation is not deterministic: the same request
// can pass on a second attempt, so retry once before giving up.
const MAX_MODERATION_ATTEMPTS = 2;

function extensionFor(mimeType: string): string {
  if (mimeType === "image/png") return "png";
  if (mimeType === "image/webp") return "webp";
  return "jpg";
}

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

  let lastError: ImageProviderError | null = null;

  for (let attempt = 1; attempt <= MAX_MODERATION_ATTEMPTS; attempt++) {
    // FormData must be rebuilt for every attempt (the body is consumed).
    const form = new FormData();
    form.append("model", OPENAI_MODEL);
    form.append("prompt", prompt);
    form.append("background", "transparent");
    form.append("output_format", "png");

    references.forEach((ref, i) => {
      form.append(
        "image[]",
        new Blob([ref.bytes as BlobPart], { type: ref.mimeType }),
        `reference_${i}.${extensionFor(ref.mimeType)}`,
      );
    });

    const response = await fetch(OPENAI_EDIT_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey()}` },
      body: form,
    });

    if (response.ok) {
      return await parseImageResponse(response);
    }

    const errText = await response.text();
    let code: string | null = null;
    try {
      code = JSON.parse(errText)?.error?.code ?? null;
    } catch {
      // body wasn't JSON: keep code = null
    }
    lastError = new ImageProviderError(
      `OpenAI image API error ${response.status}: ${errText}`,
      response.status,
      code,
    );

    if (code !== "moderation_blocked") throw lastError;
    console.warn(`Image blocked by moderation (attempt ${attempt}/${MAX_MODERATION_ATTEMPTS}).`);
  }

  throw lastError!;
}

async function parseImageResponse(response: Response): Promise<GeneratedImage> {
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
