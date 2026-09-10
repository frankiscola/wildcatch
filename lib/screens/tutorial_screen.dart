import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/type_badge_assets.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import 'home_screen.dart';

/// Un singolo passaggio in un diagramma a frecce (icona in un
/// cerchio colorato + didascalia opzionale sotto). Se [imageAsset] è
/// presente, mostra quell'immagine al posto di icona+colore (usato
/// per i badge dei tipi, vedi TypeBadgeAssets).
class _FlowStep {
  final IconData icon;
  final Color color;
  final String? caption;
  final bool faded; // per rappresentare uno stadio "incerto" (es. seconda evoluzione)
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
  final List<String>? arrowLabels; // etichetta sopra ciascuna freccia, opzionale

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
    title: 'Benvenuto in WildKin!',
    body: 'Fotografa un animale reale intorno a te: l\'app lo trasforma in una '
        'creatura da collezione tutta sua. Più animali fotografi, più ne scopri.',
  ),
  _TutorialPage(
    icon: Icons.camera_alt,
    title: 'Come si cattura',
    body: 'Punta la fotocamera sull\'animale e tienila ferma: scatta da sola '
        'appena sei stabile (oppure premi il pulsante quando vuoi tu). Niente '
        'foto dalla galleria: deve essere un animale reale, visto ora.',
    flow: [
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.sapphireBlue, caption: 'Inquadri'),
      const _FlowStep(icon: Icons.pets, color: AppColors.grassGreen, caption: 'Animale reale'),
      const _FlowStep(icon: Icons.catching_pokemon, color: AppColors.rubyRed, caption: 'Creatura'),
    ],
  ),
  _TutorialPage(
    icon: Icons.timer,
    title: 'Due scatti per essere sicuri',
    body: 'Dopo il primo scatto hai 20 minuti per confermare, ritrovando lo '
        'stesso animale e fotografandolo di nuovo da vicino a dove l\'hai '
        'visto la prima volta. Serve a essere sicuri che sia vero, non una '
        'foto trovata online.',
    flow: [
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.sapphireBlue, caption: '1° scatto'),
      const _FlowStep(icon: Icons.camera_alt, color: AppColors.sapphireBlue, caption: '2° scatto'),
      const _FlowStep(icon: Icons.check_circle, color: AppColors.grassGreen, caption: 'Cattura!'),
    ],
    arrowLabels: ['entro 20 min', ''],
  ),
  _TutorialPage(
    icon: Icons.public,
    title: 'Il tipo dipende da dove sei',
    body: 'Il tipo della creatura non è casuale del tutto: dipende dal meteo, '
        'l\'ora del giorno, la stagione e il luogo. Qui un esempio: giornata '
        'calda d\'estate. Trovi tutti i dettagli nel menu Aiuto.',
    flow: [
      const _FlowStep(icon: Icons.wb_sunny, color: Color(0xFFF2A93B), caption: 'Caldo, estate'),
      _FlowStep(
        icon: Icons.circle,
        color: Colors.transparent,
        caption: 'Fuoco',
        imageAsset: TypeBadgeAssets.of('fuoco'),
      ),
      _FlowStep(
        icon: Icons.circle,
        color: Colors.transparent,
        caption: 'Terra',
        imageAsset: TypeBadgeAssets.of('terra'),
      ),
    ],
  ),
  _TutorialPage(
    icon: Icons.upgrade,
    title: 'Le creature crescono ed evolvono',
    body: 'Ogni creatura parte al livello 5 con un solo tipo. Con il tempo può '
        'evolversi una o due volte, guadagnando un secondo tipo legato al '
        'luogo e al momento dell\'evoluzione. Non saprai mai il livello '
        'esatto: solo un indizio approssimativo.',
    flow: [
      const _FlowStep(icon: Icons.pets, color: AppColors.sapphireBlue, caption: 'Base\nLv. 5'),
      const _FlowStep(icon: Icons.pets, color: AppColors.grassGreen, caption: '2° stadio'),
      const _FlowStep(icon: Icons.pets, color: AppColors.rubyRed, caption: '3° stadio?', faded: true),
    ],
    arrowLabels: ['?', '?'],
  ),
  const _TutorialPage(
    icon: Icons.catching_pokemon,
    title: 'Livelli, mosse e battaglie',
    body: 'Le creature salgono di livello combattendo contro altri animali che '
        'fotografi. Iniziano con 4 mosse legate al loro tipo e ne sbloccano di '
        'più forti crescendo. Più indebolisci un animale in battaglia, più '
        'facile sarà catturarlo.',
    flow: [
      _FlowStep(icon: Icons.sports_martial_arts, color: AppColors.rubyRed, caption: 'Battaglia'),
      _FlowStep(icon: Icons.trending_up, color: AppColors.grassGreen, caption: 'Sale di livello'),
      _FlowStep(icon: Icons.auto_fix_high, color: AppColors.sapphireBlue, caption: 'Mossa nuova'),
    ],
  ),
];

/// Tutorial a pagine. Mostrato automaticamente al primo avvio (vedi
/// AppGate), oppure richiamabile in ogni momento dal menu Aiuto sulla
/// home — in quel caso [isFirstLaunch] è false e "chiudi" torna
/// semplicemente indietro invece di andare alla home.
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
                    widget.isFirstLaunch ? 'SALTA' : 'CHIUDI',
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
                  label: isLast ? 'INIZIA!' : 'AVANTI',
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

/// Diagramma "icona → freccia → icona" usato per illustrare i concetti
/// del tutorial senza dover disegnare vere illustrazioni: solo forme
/// geometriche generiche (cerchi, icone Material, frecce), niente
/// materiale protetto da copyright.
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
            color: active ? AppColors.rubyRed : AppColors.panelBrown.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
