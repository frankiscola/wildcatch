// Le immagini che escono dai modelli di generazione (OpenAI incluso)
// sono sempre ad alta risoluzione (1024x1024 o più) e piene di
// sfumature/anti-aliasing: anche chiedendo "stile pixel art", il
// risultato NON ha davvero pochi pixel né una palette ridotta, quindi
// il PNG compresso resta pesantissimo (la compressione senza perdita
// sfrutta aree di colore identico, che qui non esistono).
//
// Ridimensionare a una vera risoluzione da sprite dopo la
// generazione, prima di caricarlo su Supabase, risolve la
// stragrande maggioranza del problema di peso — e per inciso rende
// il risultato visivamente più coerente con lo stile retrò scelto
// per il resto dell'app (font/dialog box in stile GBA).
//
// Se 128px non bastasse a portare i file a un peso sufficientemente
// piccolo, il prossimo passo (non ancora implementato qui) sarebbe
// ridurre anche la palette di colori (es. a 32-64 colori), che
// comprime molto meglio dello sfumato che esce dai modelli — ma vale
// la pena provare prima il solo ridimensionamento.

import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";

/// Ridimensiona i byte PNG/JPEG in ingresso a un quadrato
/// [size]x[size], preservando il canale alpha se presente. Ritorna
/// sempre PNG (serve per mantenere la trasparenza).
export async function resizeToSpriteSize(bytes: Uint8Array, size = 128): Promise<Uint8Array> {
  const image = await Image.decode(bytes);
  const resized = image.resize(size, size);
  return await resized.encode(); // encode() di ImageScript produce PNG per default
}
