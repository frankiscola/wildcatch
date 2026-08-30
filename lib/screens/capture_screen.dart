import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import '../providers/capture_flow_provider.dart';
import 'generating_screen.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  Uint8List? _previewBytes;
  final _picker = ImagePicker();

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1400,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _previewBytes = bytes);
  }

  Future<void> _confirmAndGenerate() async {
    final bytes = _previewBytes;
    if (bytes == null) return;

    // TODO: in produzione recuperare l'id utente reale da un flusso
    // di autenticazione Supabase (anche anonima va bene per iniziare).
    final userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'anonymous-user';

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GeneratingScreen()),
    );

    await ref
        .read(captureFlowProvider.notifier)
        .startCapture(photoBytes: bytes, userId: userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CATTURA')),
      body: RouteBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(child: _PhotoFrame(bytes: _previewBytes)),
                const SizedBox(height: 16),
                GbaDialogBox(
                  text: _previewBytes == null
                      ? 'Inquadra l\'animale e scatta una foto per iniziare la cattura!'
                      : 'Buona foto! Premi CATTURA per vedere cosa si nasconde dentro.',
                  fontSize: 17,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: 'FOTOCAMERA',
                        icon: Icons.camera_alt,
                        onPressed: () => _pickPhoto(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelButton(
                        label: 'GALLERIA',
                        icon: Icons.photo_library,
                        background: AppColors.sapphireBlue,
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PixelButton(
                  label: 'CATTURA!',
                  icon: Icons.catching_pokemon,
                  background: AppColors.grassGreen,
                  onPressed: _previewBytes == null ? null : _confirmAndGenerate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoFrame extends StatelessWidget {
  final Uint8List? bytes;

  const _PhotoFrame({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? Center(
              child: Icon(
                Icons.pets,
                size: 64,
                color: AppColors.textMuted,
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity),
            ),
    );
  }
}
