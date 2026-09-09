// Hash percettivo (average hash, "aHash") usato per due controlli
// del meccanismo 5 (doppio avvistamento):
//
//  1. Confronto TRA le due foto dello stesso utente: se sono
//     IDENTICHE (o quasi), è quasi certo che l'utente abbia
//     semplicemente rifotografato la stessa immagine statica invece
//     di ritrovare davvero l'animale — va rifiutato.
//  2. Confronto della nuova foto con TUTTE le foto già viste da altri
//     utenti (tabella globale photo_hashes): se combacia troppo da
//     vicino con una foto di uno sconosciuto, è quasi certamente
//     un'immagine presa da internet, non uno scatto dal vivo — va
//     rifiutato/segnalato.
//
// L'algoritmo (aHash) è deliberatamente semplice: ridimensiona a 8x8
// in scala di grigi, confronta ogni pixel con la media, produce un
// hash a 64 bit. Non è robusto quanto pHash/dHash basati su DCT, ma è
// più che sufficiente per questi due controlli e non richiede
// dipendenze pesanti.

// Versione verificata al momento della scrittura di questo file
// (settembre 2026): controlla comunque su https://deno.land/x/imagescript
// se ne è uscita una più recente prima del deploy.
import { Image } from "https://deno.land/x/[email protected]/mod.ts";

/// Calcola l'aHash (64 bit, come stringa esadecimale a 16 caratteri)
/// di un'immagine scaricata da `photoUrl`.
export async function computeAverageHash(photoUrl: string): Promise<string> {
  const response = await fetch(photoUrl);
  if (!response.ok) {
    throw new Error(`Foto non raggiungibile per l'hashing: ${response.status}`);
  }
  const bytes = new Uint8Array(await response.arrayBuffer());

  const image = await Image.decode(bytes);
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

  // Da stringa binaria a esadecimale, per un campo testuale compatto
  // da salvare/indicizzare in Postgres.
  let hex = "";
  for (let i = 0; i < bits.length; i += 4) {
    hex += parseInt(bits.slice(i, i + 4), 2).toString(16);
  }
  return hex;
}

/// Distanza di Hamming tra due hash esadecimali della stessa lunghezza
/// (numero di bit diversi: 0 = identiche, 64 = completamente opposte).
export function hammingDistance(hexA: string, hexB: string): number {
  if (hexA.length !== hexB.length) {
    // Non dovrebbe mai succedere se generiamo sempre hash della
    // stessa lunghezza, ma meglio non far esplodere la function per
    // un dato corrotto: trattalo come "massimamente diverso".
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
