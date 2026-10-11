// Sprite-generation orchestration: front from the real photo, then
// back chained from the front (not from the original photo, for
// visual consistency — see the discussion in the project), with an
// automatic plausibility check and a single retry if the back
// doesn't look like the same creature as the front.

//
// NO absolute guarantee: no current model actually reconstructs the
// creature in 3D to "turn the camera around" — it's making a
// plausible guess. This file reduces the rate of obvious mistakes,
// it doesn't eliminate it — see also the "regenerate" button on the
// UI side as the last safety net (still to be added on the Flutter
// side).

import { askAboutImages, generateImage, type ImageReference } from "./image_generation_client.ts";
import { resizeToSpriteSize } from "./sprite_postprocess.ts";
import {
  BACK_PROMPT,
  buildSpritePrompt,
  EVOLUTION_1_PROMPT,
  EVOLUTION_2_PROMPT,
  FRONT_PROMPT,
} from "./sprite_prompts.ts";

const SPRITE_SIZE = 128; // see sprite_postprocess.ts for why

export interface SpriteResult {
  front: ImageReference;
  back: ImageReference;
}

export async function generateSprites(
  photo: ImageReference,
  speciesHint: string | null,
  types: string[],
): Promise<SpriteResult> {
  const front = await generateImage(
    buildSpritePrompt(FRONT_PROMPT, types, speciesHint),
    [photo],
  );
  return await completeWithBack(front, speciesHint, types);
}

/// Sprites for an EVOLVED form. [previousFront] is the front sprite of
/// the previous stage (stage 1 -> the base form's front; stage 2 -> the
/// first evolution's front), passed as the reference image so "same
/// subject" actually means something. [types] should be the types the
/// creature has AFTER evolving.
///
/// NOTE: not called from anywhere yet — evolution is resolved client
/// side today and there are no per-stage sprite columns. Also, stored
/// sprites are 128x128, a low-resolution reference for the model.
export async function generateEvolutionSprites(
  previousFront: ImageReference,
  stage: 1 | 2,
  speciesHint: string | null,
  types: string[],
): Promise<SpriteResult> {
  const template = stage === 1 ? EVOLUTION_1_PROMPT : EVOLUTION_2_PROMPT;
  const front = await generateImage(
    buildSpritePrompt(template, types, speciesHint),
    [previousFront],
  );
  return await completeWithBack(front, speciesHint, types);
}

/// Shared tail of both pipelines: back view chained from the front,
/// plausibility check with one retry, then resize.
async function completeWithBack(
  front: ImageReference,
  speciesHint: string | null,
  types: string[],
): Promise<SpriteResult> {
  const backPrompt = buildSpritePrompt(BACK_PROMPT, types, speciesHint);
  let back = await generateImage(backPrompt, [front]);

  const plausible = await backLooksLikeSameCreature(front, back);
  if (!plausible) {
    // Generation isn't deterministic: a second attempt with the
    // exact same prompt is often enough to correct course.
    back = await generateImage(backPrompt, [front]);
  }

  // Resize ONLY at the end: the plausibility check above works on
  // the full-resolution images, where the vision model has more
  // detail to judge from.
  const [frontSprite, backSprite] = await Promise.all([
    resizeToSpriteSize(front.bytes, SPRITE_SIZE),
    resizeToSpriteSize(back.bytes, SPRITE_SIZE),
  ]);

  return {
    front: { bytes: frontSprite, mimeType: "image/png" },
    back: { bytes: backSprite, mimeType: "image/png" },
  };
}

/// Cheap plausibility check: asks the model itself whether the two
/// images look like the same creature seen from the front and from
/// behind. Fails "open" (true) on an ambiguous answer or network
/// error: better to show an imperfect sprite than to block the
/// capture over a problem in the check itself.
async function backLooksLikeSameCreature(
  front: ImageReference,
  back: ImageReference,
): Promise<boolean> {
  try {
    const answer = await askAboutImages(
      "The first image is the front of a creature, the second should " +
        "be the same creature seen from behind. Do they clearly share " +
        "the same color palette, the same overall shape, and the same " +
        "pose? Answer with a single word: YES or NO.",
      [front, back],
    );
    const normalized = answer.trim().toUpperCase();
    return !normalized.startsWith("NO");
  } catch (e) {
    console.error("Front/back plausibility check failed, proceeding anyway:", e);
    return true;
  }
}
