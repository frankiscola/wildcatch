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

const SPRITE_SIZE = 128; // see sprite_postprocess.ts for why

const STYLE_PROMPT =
  "Reinterpret the subject as a collectible creature in a retro " +
  "video-game style (chibi proportions, thick black outlines, flat " +
  "colors, soft lighting, single neutral-colored background), " +
  "an original design, not modeled on any existing character. " +
  "Full-body framing.";

const BACK_PROMPT =
  "The exact same creature as in the attached image: same color " +
  "palette, same standing pose, same accessories/patterns. Show it, " +
  "however, viewed EXACTLY from behind (not 3/4): head not visible or " +
  "only in profile, limbs mirrored relative to the front view. A " +
  "slightly simpler and less detailed version than the front, as is " +
  "typical of back sprites in this kind of game.";

export interface SpriteResult {
  front: ImageReference;
  back: ImageReference;
}

export async function generateSprites(
  photo: ImageReference,
  speciesHint: string | null,
): Promise<SpriteResult> {
  const speciesNote = speciesHint ? `The subject is an animal of the "${speciesHint}" kind. ` : "";

  const front = await generateImage(
    `${speciesNote}${STYLE_PROMPT} Front view, the subject looking toward the camera.`,
    [photo],
  );

  let back = await generateImage(BACK_PROMPT, [front]);

  const plausible = await backLooksLikeSameCreature(front, back);
  if (!plausible) {
    // Generation isn't deterministic: a second attempt with the
    // exact same prompt is often enough to correct course.
    back = await generateImage(BACK_PROMPT, [front]);
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
