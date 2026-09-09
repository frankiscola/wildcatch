import 'package:flutter/services.dart';

/// Meccanismo 2 del piano anti-cattura-da-internet: verifica di
/// profondità reale.
///
/// STATO ATTUALE: scaffold, NON implementato lato nativo.
///
/// Molti telefoni espongono una mappa di profondità della scena
/// (LiDAR/TrueDepth su iOS via AVDepthData, dual-camera stereo o
/// ToF su Android via il flusso ImageFormat.DEPTH16 di Camera2).
/// Se la profondità nella zona centrale dell'inquadratura è quasi
/// costante, la scena è quasi certamente un piano piatto (schermo,
/// foto stampata) invece di un animale reale a distanza variabile
/// dallo sfondo.
///
/// Implementarlo per bene richiede codice nativo Swift/Kotlin che
/// non posso scrivere "alla cieca" senza un device per testarlo: un
/// bug qui non darebbe un errore di compilazione ma un semplice
/// "funziona sempre/non funziona mai", difficile da notare prima di
/// spedire l'app. Per questo il servizio è scritto per degradare in
/// modo esplicito ed essere SEMPRE opzionale: se il canale nativo non
/// risponde, il resto della pipeline (mosse 1, 3, 4, 5) continua a
/// funzionare esattamente come se questo segnale non esistesse.
///
/// Per attivarlo davvero in futuro:
///  - iOS: implementare in AppDelegate.swift un MethodChannel che usa
///    AVCaptureDepthDataOutput per leggere la varianza di profondità
///    al centro del frame durante lo scatto.
///  - Android: implementare in MainActivity.kt un MethodChannel che
///    usa Camera2 (CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL
///    + uno stream ImageFormat.DEPTH16, se il device lo supporta) per
///    calcolare la stessa varianza.
/// In entrambi i casi il canale deve rispondere con `null` (non con
/// un valore finto) sui device che non hanno hardware di profondità.
class DepthCheckService {
  static const _channel = MethodChannel('wildcatch/depth');

  /// Ritorna la varianza di profondità stimata al centro
  /// dell'inquadratura, oppure `null` se il device/la piattaforma non
  /// espone questo dato (caso atteso oggi, su OGNI device, finché il
  /// canale nativo non viene implementato).
  ///
  /// Un valore vicino a 0 = superficie piatta rilevata (sospetto).
  /// Un valore alto = profondità variabile = scena 3D reale.
  Future<double?> sampleCenterDepthVariance() async {
    try {
      final result = await _channel.invokeMethod<double>('sampleCenterDepthVariance');
      return result;
    } on MissingPluginException {
      // Atteso finché non si scrive il codice nativo: nessun errore
      // da mostrare all'utente, semplicemente "segnale non disponibile".
      return null;
    } on PlatformException {
      return null;
    }
  }
}
