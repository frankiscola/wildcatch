import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/type_badge_assets.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import 'home_screen.dart';

/// A single step in an arrow diagram (an icon in a colored circle +
/// an optional caption below). If [imageAsset] is set, that image is
/// shown instead of icon+color (used for type badges, see
/// TypeBadgeAssets).
class _FlowStep {
  final IconData icon;
  final Color color;
  final String? caption;
  final bool faded; // used to represent an "uncertain" stage (e.g. second evolution)
  final String? imageAsset;

  const _FlowStep({
    required this.icon,
    required this.color,
    this.caption,
    this.faded = false,
    this.imageAsset,
  });
}

class _TutorialPage {
  final IconData icon;
  final String title;
  final String body;
  final List<_FlowStep>? flow;
  final List<String>? arrowLabels; // label above each arrow, optional

  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
    this.flow,
    this.arrowLabels,
  });
}

final _pages = [
  const _TutorialPage(
    icon: Icons.auto_awesome,
    title: 'Welcome to Wildkin!',
    body: 'Photograph a real animal around you: the app turns it into a '
        'one-of-a-kind collectible Wildkin. The more animals you photograph, '
        'the more you discover.',
  ),
  _TutorialPage(
    icon: Icons.camera_alt,
    title: 'How to capture',
    body: 'Point the camera at the animal and hold it steady: it fires on '
        'its own once you\'re stable (or press the button whenever you want). '
        'No photos from the gallery: it has to be a real animal, seen right now.',
    flow: [
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.tidalBlue, caption: 'You aim'),
      const _FlowStep(icon: Icons.pets, color: AppColors.grassGreen, caption: 'Real animal'),
      const _FlowStep(icon: Icons.auto_awesome, color: AppColors.emberRed, caption: 'Wildkin'),
    ],
  ),
  _TutorialPage(
    icon: Icons.timer,
    title: 'Two shots to be sure',
    body: 'After the first shot you have 20 minutes to confirm, by finding '
        'the same animal again and photographing it close to where you first '
        'saw it. This makes sure it\'s real, not a photo found online.',
    flow: [
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.tidalBlue, caption: '1st shot'),
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.tidalBlue, caption: '2nd shot'),
      const _FlowStep(icon: Icons.check_circle, color: AppColors.grassGreen, caption: 'Captured!'),
    ],
    arrowLabels: ['within 20 min', ''],
  ),
  _TutorialPage(
    icon: Icons.public,
    title: 'The type depends on where you are',
    body: 'A Wildkin\'s type isn\'t entirely random: it depends on the '
        'weather, time of day, season, and place. Here\'s an example: a hot '
        'summer day. Find all the details in the Help menu.',
    flow: [
      const _FlowStep(icon: Icons.wb_sunny, color: Color(0xFFF2A93B), caption: 'Hot, summer'),
      _FlowStep(
        icon: Icons.circle,
        color: Colors.transparent,
        caption: 'Fire',
        imageAsset: TypeBadgeAssets.of('fire'),
      ),
      _FlowStep(
        icon: Icons.circle,
        color: Colors.transparent,
        caption: 'Ground',
        imageAsset: TypeBadgeAssets.of('ground'),
      ),
    ],
  ),
  _TutorialPage(
    icon: Icons.upgrade,
    title: 'Wildkin grow and evolve',
    body: 'Every Wildkin starts at level 5 with a single type. Over time it '
        'can evolve once or twice, gaining a second type tied to the place '
        'and moment of the evolution. You\'ll never know the exact level: '
        'only a rough hint.',
    flow: [
      const _FlowStep(icon: Icons.pets, color: AppColors.tidalBlue, caption: 'Base\nLv. 5'),
      const _FlowStep(icon: Icons.pets, color: AppColors.grassGreen, caption: 'Stage 2'),
      const _FlowStep(icon: Icons.pets, color: AppColors.emberRed, caption: 'Stage 3?', faded: true),
    ],
    arrowLabels: ['?', '?'],
  ),
  const _TutorialPage(
    icon: Icons.sports_martial_arts,
    title: 'Levels, moves, and battles',
    body: 'Wildkin level up by battling other animals you photograph. They '
        'start with 4 moves tied to their type and unlock stronger ones as '
        'they grow. The more you weaken an animal in battle, the easier it '
        'will be to catch.',
    flow: [
      _FlowStep(icon: Icons.sports_martial_arts, color: AppColors.emberRed, caption: 'Battle'),
      _FlowStep(icon: Icons.trending_up, color: AppColors.grassGreen, caption: 'Levels up'),
      _FlowStep(icon: Icons.auto_fix_high, color: AppColors.tidalBlue, caption: 'New move'),
    ],
  ),
];

/// Page-based tutorial. Shown automatically on first launch (see
/// AppGate), or reachable anytime from the Help menu on the home
/// screen — in that case [isFirstLaunch] is false and "close" simply
/// goes back instead of going to the home screen.
class TutorialScreen extends StatefulWidget {
  final bool isFirstLaunch;

  const TutorialScreen({super.key, this.isFirstLaunch = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial', true);
    if (!mounted) return;

    if (widget.isFirstLaunch) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: RouteBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    widget.isFirstLaunch ? 'SKIP' : 'CLOSE',
                    style: AppFonts.body(color: AppColors.panelBrown, fontSize: 15),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _TutorialPageView(page: _pages[i]),
                ),
              ),
              _DotsIndicator(count: _pages.length, current: _page),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: PixelButton(
                  label: isLast ? 'START!' : 'NEXT',
                  icon: isLast ? Icons.play_arrow : Icons.arrow_forward,
                  background: AppColors.grassGreen,
                  onPressed: _next,
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialPageView extends StatelessWidget {
  final _TutorialPage page;

  const _TutorialPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 6)),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppFonts.pixelTitle(fontSize: 19, color: AppColors.panelBrown),
          ),
          if (page.flow != null) ...[
            const SizedBox(height: 20),
            _FlowDiagram(steps: page.flow!, arrowLabels: page.arrowLabels),
          ],
          const SizedBox(height: 18),
          GbaDialogBox(text: page.body, fontSize: 15),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// "Icon → arrow → icon" diagram used to illustrate the tutorial's
/// concepts without needing real illustrations: just generic
/// geometric shapes (circles, Material icons, arrows), no
/// copyrighted material.
class _FlowDiagram extends StatelessWidget {
  final List<_FlowStep> steps;
  final List<String>? arrowLabels;

  const _FlowDiagram({required this.steps, this.arrowLabels});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      children.add(_FlowNode(step: steps[i]));
      if (i < steps.length - 1) {
        final label = arrowLabels != null && i < arrowLabels!.length ? arrowLabels![i] : null;
        children.add(_FlowArrow(label: label));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _FlowNode extends StatelessWidget {
  final _FlowStep step;

  const _FlowNode({required this.step});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: step.faded ? 0.45 : 1.0,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            if (step.imageAsset != null)
              SizedBox(
                width: 52,
                height: 52,
                child: Image.asset(step.imageAsset!, fit: BoxFit.contain),
              )
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: step.color,
                  shape: BoxShape.circle,
                  border: step.faded
                      ? Border.all(color: AppColors.panelBrown, width: 1.5, style: BorderStyle.solid)
                      : null,
                ),
                child: Icon(step.icon, color: Colors.white, size: 26),
              ),
            if (step.caption != null) ...[
              const SizedBox(height: 6),
              Text(
                step.caption!,
                textAlign: TextAlign.center,
                style: AppFonts.body(fontSize: 11, color: AppColors.panelBrown),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  final String? label;

  const _FlowArrow({this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          if (label != null && label!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label!,
                style: AppFonts.body(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          Icon(Icons.arrow_forward, color: AppColors.panelBrown.withOpacity(0.6), size: 22),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;

  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.emberRed : AppColors.panelBrown.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
