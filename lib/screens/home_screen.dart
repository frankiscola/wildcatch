import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/capture_context.dart';
import '../services/context_builder.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/location_prompt_dialog.dart';
import '../widgets/route_background.dart';
import '../widgets/sprite_image.dart';
import '../providers/capture_flow_provider.dart';
import 'battle_online_screen.dart';
import 'capture_screen.dart';
import 'collection_screen.dart';
import 'field_journal_screen.dart';
import 'help_screen.dart';
import 'team_screen.dart';

/// The app's main screen — "explorer's notebook" style: a hero
/// capture button up top, and below it a stack of cards for each
/// section, each with a small live preview of its own content
/// (latest catch, current team lineup, journal count...) so the
/// home screen feels alive rather than a static list of labels.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _locationService = LocationService();
  CaptureContext? _status;
  bool _statusFailed = false;

  @override
  void initState() {
    super.initState();
    _loadStatusStrip();
  }

  /// Best-effort weather/biome preview for the top strip. Never
  /// blocks the rest of the screen and fails silently — this is a
  /// nice-to-have, not something worth an error state over.
  Future<void> _loadStatusStrip() async {
    try {
      final context = await ContextBuilder().buildCurrentContext();
      if (mounted) setState(() => _status = context);
    } catch (_) {
      if (mounted) setState(() => _statusFailed = true);
    }
  }

  Future<void> _startNewCapture() async {
    final enabled = await _locationService.isServiceEnabled();
    if (enabled) {
      _openCaptureScreen();
      return;
    }
    if (!mounted) return;
    final enabledNow = await showLocationRequiredDialog(context);
    if (enabledNow && mounted) {
      _openCaptureScreen();
    }
  }

  void _openCaptureScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final wildkinAsync = ref.watch(myWildkinProvider);
    final battleLogsAsync = ref.watch(battleLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WILDKIN'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _open(const HelpScreen()),
          ),
        ],
      ),
      body: RouteBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_status != null || !_statusFailed) _StatusStrip(status: _status),
              const SizedBox(height: 14),
              _CaptureHero(onTap: _startNewCapture),
              const SizedBox(height: 18),
              wildkinAsync.when(
                data: (wildkinList) => battleLogsAsync.when(
                  data: (logs) => _JournalCard(
                    onTap: () => _open(const FieldJournalScreen()),
                    entryCount: wildkinList.length + logs.length,
                    previewUrls: [
                      ...wildkinList.map((w) => w.frontSpriteUrl),
                      ...logs.map((l) => l.photoUrl),
                    ].take(3).toList(),
                  ),
                  loading: () => const _LoadingCard(title: 'FIELD JOURNAL'),
                  error: (_, __) => _JournalCard(
                    onTap: () => _open(const FieldJournalScreen()),
                    entryCount: wildkinList.length,
                    previewUrls: wildkinList.map((w) => w.frontSpriteUrl).take(3).toList(),
                  ),
                ),
                loading: () => const _LoadingCard(title: 'FIELD JOURNAL'),
                error: (_, __) => _ExplorerCard(
                  accentColor: AppColors.tidalBlue,
                  icon: Icons.menu_book,
                  title: 'FIELD JOURNAL',
                  subtitle: 'Every Wildkin you\'ve encountered',
                  onTap: () => _open(const FieldJournalScreen()),
                ),
              ),
              const SizedBox(height: 12),
              wildkinAsync.when(
                data: (wildkinList) => _CollectionCard(
                  onTap: () => _open(const CollectionScreen()),
                  wildkinList: wildkinList,
                ),
                loading: () => const _LoadingCard(title: 'COLLECTION'),
                error: (_, __) => _ExplorerCard(
                  accentColor: AppColors.grassGreen,
                  icon: Icons.style,
                  title: 'COLLECTION',
                  subtitle: 'Wildkin you own',
                  onTap: () => _open(const CollectionScreen()),
                ),
              ),
              const SizedBox(height: 12),
              wildkinAsync.when(
                data: (wildkinList) => _TeamCard(
                  onTap: () => _open(const TeamScreen()),
                  team: wildkinList.where((w) => w.isInTeam).toList(),
                ),
                loading: () => const _LoadingCard(title: 'TEAM'),
                error: (_, __) => _ExplorerCard(
                  accentColor: AppColors.captureOrbGold,
                  icon: Icons.groups,
                  title: 'TEAM',
                  subtitle: 'Your active squad',
                  onTap: () => _open(const TeamScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _ExplorerCard(
                accentColor: AppColors.emberRed,
                icon: Icons.bolt,
                title: 'ONLINE BATTLE',
                subtitle: 'Challenge other trainers',
                badge: 'SOON',
                onTap: () => _open(const BattleOnlineScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill at the top showing the current weather/biome, since
/// both directly influence what you catch — a nice, cheap reminder
/// that the world state matters. Hides itself if the fetch failed.
class _StatusStrip extends StatelessWidget {
  final CaptureContext? status;
  const _StatusStrip({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const SizedBox(
        height: 30,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.panelCream),
          ),
        ),
      );
    }

    final weatherIcon = switch (status!.weatherCondition) {
      'rain' => Icons.water_drop,
      'storm' => Icons.thunderstorm,
      'snow' => Icons.ac_unit,
      'fog' => Icons.foggy,
      _ => Icons.wb_sunny,
    };
    final biomeLabel = switch (status!.biome) {
      Biome.sea => 'Coast',
      Biome.mountain => 'Mountains',
      Biome.forest => 'Forest',
      Biome.urbanCity => 'City',
      Biome.plain => 'Plains',
      Biome.desert => 'Desert',
      Biome.unknown => 'Unknown area',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panelCream.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(weatherIcon, size: 16, color: AppColors.tidalBlue),
          const SizedBox(width: 6),
          Text(biomeLabel, style: AppFonts.body(fontSize: 12, color: AppColors.panelBrown)),
          const SizedBox(width: 6),
          Text(
            '· ${status!.temperatureCelsius.round()}°C',
            style: AppFonts.body(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The big, always-visible primary action — deliberately the first
/// full-width, high-contrast element on the screen.
class _CaptureHero extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: AppColors.shadowSoft, blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: AppColors.panelCream, size: 30),
            const SizedBox(width: 12),
            Text(
              'NEW CAPTURE',
              style: AppFonts.pixelTitle(fontSize: 16, color: AppColors.panelCream),
            ),
          ],
        ),
      ),
    );
  }
}

/// Base horizontal card shared by every section shortcut: colored
/// accent stripe on the left, icon, title/subtitle, optional "SOON"
/// badge, chevron on the right. Subclasses below build the preview
/// thumbnails that go where [trailingPreview] is passed.
class _ExplorerCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Widget? trailingPreview;
  final VoidCallback onTap;

  const _ExplorerCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.trailingPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: AppColors.panelCream,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 92,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppFonts.pixelTitle(fontSize: 11, color: AppColors.panelBrown),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: AppFonts.pixelTitle(fontSize: 7, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.body(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (trailingPreview != null) ...[trailingPreview!, const SizedBox(width: 8)],
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  final String url;
  const _PreviewThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: AppColors.routeSkyBottom,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.panelCream, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: SpriteImage(url: url),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final VoidCallback onTap;
  final int entryCount;
  final List<String> previewUrls;

  const _JournalCard({required this.onTap, required this.entryCount, required this.previewUrls});

  @override
  Widget build(BuildContext context) {
    return _ExplorerCard(
      accentColor: AppColors.tidalBlue,
      icon: Icons.menu_book,
      title: 'FIELD JOURNAL',
      subtitle: entryCount == 0
          ? 'No encounters yet'
          : '$entryCount Wildkin encountered',
      onTap: onTap,
      trailingPreview: previewUrls.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: previewUrls.map((u) => _PreviewThumb(url: u)).toList(),
            ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final VoidCallback onTap;
  final List<dynamic> wildkinList;

  const _CollectionCard({required this.onTap, required this.wildkinList});

  @override
  Widget build(BuildContext context) {
    final latest = wildkinList.isEmpty ? null : wildkinList.first;
    return _ExplorerCard(
      accentColor: AppColors.grassGreen,
      icon: Icons.style,
      title: 'COLLECTION',
      subtitle: wildkinList.isEmpty
          ? 'Nothing caught yet'
          : '${wildkinList.length} Wildkin owned',
      onTap: onTap,
      trailingPreview: latest == null ? null : _PreviewThumb(url: latest.frontSpriteUrl as String),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final VoidCallback onTap;
  final List<dynamic> team;

  const _TeamCard({required this.onTap, required this.team});

  @override
  Widget build(BuildContext context) {
    return _ExplorerCard(
      accentColor: AppColors.captureOrbGold,
      icon: Icons.groups,
      title: 'TEAM',
      subtitle: team.isEmpty ? 'No active squad yet' : '${team.length}/4 ready to battle',
      onTap: onTap,
      trailingPreview: team.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: team.take(4).map((w) => _PreviewThumb(url: w.frontSpriteUrl as String)).toList(),
            ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String title;
  const _LoadingCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: AppColors.panelCream.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.tidalBlue),
      ),
    );
  }
}
