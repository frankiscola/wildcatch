// Images coming out of generation models (OpenAI included) are
// always high-resolution (1024x1024 or more) and full of
// gradients/anti-aliasing: even when asking for a "pixel art style",
// the result does NOT actually have few pixels or a reduced palette,
// so the compressed PNG stays very heavy (lossless compression
// relies on areas of identical color, which don't exist here).
//
// Resizing to an actual sprite resolution after generation, before
// uploading to Supabase, solves the vast majority of the file-size
// problem — and incidentally makes the result visually more
// consistent with the retro style chosen for the rest of the app
// (GBA-style fonts/dialog boxes).
//
// If 128px isn't enough to bring file sizes down far enough, the
// next step (not implemented here yet) would be to also reduce the
// color palette (e.g. to 32-64 colors), which compresses much better
// than the gradients coming out of the models — but it's worth
// trying plain resizing first.

import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";

/// Resizes the input PNG/JPEG bytes to a [size]x[size] square,
/// preserving the alpha channel if present. Always returns PNG
/// (needed to keep transparency).
export async function resizeToSpriteSize(bytes: Uint8Array, size = 128): Promise<Uint8Array> {
  const image = await Image.decode(bytes);
  const resized = image.resize(size, size);
  return await resized.encode(); // ImageScript's encode() produces PNG by default
}
