// Sprite prompts (English versions of the project's own prompts).
//
// Placeholders: {type_hint} and {species_hint}, filled by
// buildSpritePrompt(). FRONT and BACK are used for BOTH the first
// capture and the reroll, since both go through generateSprites().
// EVOLUTION_1 / EVOLUTION_2 are used by generateEvolutionSprites(),
// which receives the previous stage's front sprite as the reference
// image (there is no photo for an evolved form: "same subject" needs
// something to refer to).
//
// PNG output and transparency are also set as API parameters in
// image_generation_client.ts; "Transparent background" stays in the
// text only as reinforcement.

// Shared style line. The target look is the Gen 3 handheld RPG
// battle sprites; described instead of named on purpose (naming a
// franchise raises the odds of output moderation blocks and of
// look-alike characters). Add the name here if you want to test it.
const STYLE =
  "128x128 px pixel art in the style of Game Boy Advance era RPG battle " +
  "sprites. Isometric. Transparent background. No ground.";

// "facing left" alone was often ignored (the model keeps the pose of
// the photo, e.g. looking straight at the camera). Spelled out more
// explicitly.
const FACING_LEFT =
  "Three-quarter view, body and head turned toward the left side of the " +
  "image, not looking at the camera.";

export const FRONT_PROMPT =
  "Sprite of an animal of {type_hint} type inspired by a {species_hint}. " +
  FACING_LEFT + " " + STYLE;

export const BACK_PROMPT =
  "Same subject, seen from behind, facing away from the viewer, slightly " +
  "turned toward the right. " + STYLE;

export const EVOLUTION_1_PROMPT =
  "Same subject seen from the front, but a stronger, more evolved form of " +
  "the same creature. It must be similar in style, but bigger-looking and " +
  "bulkier, with a more evolved design and in a different, more " +
  "aggressive pose. " + FACING_LEFT + " {type_hint} type. " +
  "Inspired by a {species_hint}. " + STYLE;

export const EVOLUTION_2_PROMPT =
  "Same subject seen from the front, but an even stronger, final evolved " +
  "form of the same creature. It must be similar in style, but " +
  "bigger-looking and bulkier, with a more evolved design and in a " +
  "different, beastly pose. " + FACING_LEFT + " {type_hint} type. " +
  "Inspired by a {species_hint}. " + STYLE;

// ---------------------------------------------------------------
// Fallback prompts, used ONLY for the retry after an output-stage
// moderation block (see generateImage's fallbackPrompt). Same
// subject and composition, but the style line no longer evokes a
// specific game generation and explicitly asks for an original
// design: the most likely reason for a block with category "other"
// is the result looking too close to an existing franchise's creature.
// ---------------------------------------------------------------

const SAFE_STYLE =
  "Original creature design, not resembling any existing character or " +
  "franchise. Clean retro pixel art, 128x128 px, limited color palette, " +
  "thick dark outlines, flat colors. Transparent background. No ground.";

export const FRONT_PROMPT_SAFE =
  "Pixel art sprite of an original animal-like creature of {type_hint} " +
  "type inspired by a {species_hint}. " + FACING_LEFT + " " + SAFE_STYLE;

export const BACK_PROMPT_SAFE =
  "Same subject, seen from behind, facing away from the viewer, slightly " +
  "turned toward the right. " + SAFE_STYLE;

export const EVOLUTION_1_PROMPT_SAFE =
  "Same subject, but a stronger, more evolved form of the same creature: " +
  "bigger-looking and bulkier, with a more evolved design and a more " +
  "aggressive pose. " + FACING_LEFT + " {type_hint} type. " +
  "Inspired by a {species_hint}. " + SAFE_STYLE;

export const EVOLUTION_2_PROMPT_SAFE =
  "Same subject, but an even stronger, final evolved form of the same " +
  "creature: bigger-looking and bulkier, with a more evolved design and " +
  "a beastly pose. " + FACING_LEFT + " {type_hint} type. " +
  "Inspired by a {species_hint}. " + SAFE_STYLE;

/// Fills {type_hint} / {species_hint}. When the species is unknown
/// (species_hint is null) the "inspired by a {species_hint}" clause is
/// dropped instead of injecting a bogus placeholder.
export function buildSpritePrompt(
  template: string,
  types: string[],
  speciesHint: string | null,
): string {
  const typeHint = types.length > 0 ? types.join(" and ") : "normal";

  let prompt = template;
  if (speciesHint) {
    prompt = prompt.replaceAll("{species_hint}", speciesHint);
  } else {
    prompt = prompt
      .replace(" inspired by a {species_hint}", "")
      .replace(" Inspired by a {species_hint}.", "");
  }
  return prompt.replaceAll("{type_hint}", typeHint);
}
