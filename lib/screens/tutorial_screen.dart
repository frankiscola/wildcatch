import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';
import '../widgets/gba_dialog_box.dart';
import '../widgets/pixel_button.dart';
import 'home_screen.dart';

class _TutorialPage {
  final IconData icon;
  final String title;
  final String body;

  const _TutorialPage({required this.icon, required this.title, required this.body});
}

const _pages = [
  _TutorialPage(
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
  ),
  _TutorialPage(
    icon: Icons.timer,
    title: 'Due scatti per essere sicuri',
    body: 'Dopo il primo scatto hai 20 minuti per confermare, ritrovando lo '
        'stesso animale e fotografandolo di nuovo da vicino a dove l\'hai '
        'visto la prima volta. Serve a essere sicuri che sia vero, non una '
        'foto trovata online.',
  ),
  _TutorialPage(
    icon: Icons.public,
    title: 'Il tipo dipende da dove sei',
    body: 'Il tipo della creatura non è casuale del tutto: dipende dal meteo, '
        'l\'ora del giorno, la stagione e il luogo. Fa caldo e sei al mare? '
        'Più probabile Acqua o Fuoco. Sei in montagna? Roccia e Terra sono '
        'favoriti. Trovi tutti i dettagli nel menu Aiuto.',
  ),
  _TutorialPage(
    icon: Icons.upgrade,
    title: 'Le creature crescono ed evolvono',
    body: 'Ogni creatura parte al livello 5 con un solo tipo. Con il tempo può '
        'evolversi una o due volte, guadagnando un secondo tipo legato al '
        'luogo e al momento dell\'evoluzione. Non saprai mai il livello '
        'esatto: solo un indizio approssimativo.',
  ),
  _TutorialPage(
    icon: Icons.catching_pokemon,
    title: 'Livelli, mosse e battaglie',
    body: 'Le creature salgono di livello combattendo contro altri animali che '
        'fotografi. Iniziano con 4 mosse legate al loro tipo e ne sbloccano di '
        'più forti crescendo. Più indebolisci un animale in battaglia, più '
        'facile sarà catturarlo.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.brandGradient,
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 6)),
              ],
            ),
            child: Icon(page.icon, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 28),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: AppFonts.pixelTitle(fontSize: 20, color: AppColors.panelBrown),
          ),
          const SizedBox(height: 18),
          GbaDialogBox(text: page.body, fontSize: 16),
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
