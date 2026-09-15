// Perceptual hash (average hash, "aHash") used for two checks in
// mechanism 5 (double sighting):
//
//  1. Comparison BETWEEN the same user's two photos: if they're
//     IDENTICAL (or nearly so), it's almost certain the user simply
//     re-photographed the same static image instead of genuinely
//     finding the animal again — reject.
//  2. Comparison of the new photo against ALL photos already seen
//     from other users (the global photo_hashes table): if it
//     matches too closely with a stranger's photo, it's almost
//     certainly an image taken from the internet, not a live shot —
//     reject/flag.
//
// The algorithm (aHash) is deliberately simple: downscale to 8x8
// grayscale, compare each pixel to the mean, produce a 64-bit hash.
// It's not as robust as DCT-based pHash/dHash, but it's more than
// enough for these two checks and needs no heavy dependencies.

// Version verified at the time this file was written (September
// 2026): still worth checking https://deno.land/x/imagescript for a
// newer one before deploying.
import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";

/// Computes the aHash (64 bits, as a 16-character hex string) of an
/// image downloaded from `photoUrl`.
export async function computeAverageHash(photoUrl: string): Promise<string> {
  const response = await fetch(photoUrl);
  if (!response.ok) {
    throw new Error(`Photo unreachable for hashing: ${response.status} (url: ${photoUrl})`);
  }

  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.startsWith("image/")) {
    throw new Error(
      `URL did not return an image (content-type: "${contentType}"). ` +
        `Check that the 'captures' bucket is public and the URL is correct: ${photoUrl}`,
    );
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  const image = await Image.decode(bytes);

  if (image.width < 1 || image.height < 1) {
    throw new Error(
      `Decoded image has invalid dimensions (${image.width}x${image.height}) for url: ${photoUrl}`,
    );
  }

  const small = image.resize(8, 8);

  const grays: number[] = [];
  for (let y = 0; y < 8; y++) {
    for (let x = 0; x < 8; x++) {
      const pixel = small.getPixelAt(x, y);
      const [r, g, b] = Image.colorToRGBA(pixel);
      grays.push(0.299 * r + 0.587 * g + 0.114 * b);
    }
  }

  const mean = grays.reduce((a, b) => a + b, 0) / grays.length;

  let bits = "";
  for (const gray of grays) {
    bits += gray >= mean ? "1" : "0";
  }

  // Binary string to hex, for a compact text field to save/index in
  // Postgres.
  let hex = "";
  for (let i = 0; i < bits.length; i += 4) {
    hex += parseInt(bits.slice(i, i + 4), 2).toString(16);
  }
  return hex;
}

/// Hamming distance between two hex hashes of the same length
/// (number of differing bits: 0 = identical, 64 = fully opposite).
export function hammingDistance(hexA: string, hexB: string): number {
  if (hexA.length !== hexB.length) {
    // Should never happen if we always generate hashes of the same
    // length, but better not to crash the function over corrupted
    // data: treat it as "maximally different".
    return 64;
  }

  let distance = 0;
  for (let i = 0; i < hexA.length; i++) {
    const a = parseInt(hexA[i], 16);
    const b = parseInt(hexB[i], 16);
    let xor = a ^ b;
    while (xor > 0) {
      distance += xor & 1;
      xor >>= 1;
    }
  }
  return distance;
}
