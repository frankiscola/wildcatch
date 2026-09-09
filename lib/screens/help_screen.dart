import 'package:flutter/material.dart';
import '../models/type_chart.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/route_background.dart';

/// Menu di aiuto/info: reference sempre disponibile su come funzionano
/// le regole del gioco, per chi non vuole rivedersi tutto il tutorial
/// a pagine solo per controllare un dettaglio (es. "quanto danno fa
/// un attacco Acqua contro un Roccia?").
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIUTO')),
      body: RouteBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              _Section(
                icon: Icons.public,
                title: 'Come si sceglie il tipo',
                body: 'Alla cattura la creatura riceve un solo tipo (raramente '
                    'due, ~35% delle volte), scelto in base a diversi fattori '
                    'del momento e del luogo:',
                bullets: [
                  'Temperatura: molto caldo favorisce Fuoco/Terra, molto '
                      'freddo favorisce Ghiaccio.',
                  'Meteo: pioggia → Acqua, temporale → Elettro, neve → '
                      'Ghiaccio, nebbia → Psico/Veleno.',
                  'Bioma: mare → Acqua, montagna → Roccia/Terra, foresta → '
                      'Erba/Coleottero, città → Elettro/Roccia, deserto → '
                      'Terra/Fuoco, pianura → Erba/Terra.',
                  'Ora del giorno: notte favorisce Buio/Psico, giorno favorisce '
                      'Volante/Coleottero.',
                  'Stagione: estate → Fuoco/Terra, inverno → Ghiaccio, '
                      'primavera → Erba/Coleottero, autunno → Terra/Buio.',
                ],
              ),
              SizedBox(height: 20),
              _Section(
                icon: Icons.upgrade,
                title: 'Evoluzione',
                body: 'Ogni creatura catturata è sempre allo stadio base, al '
                    'livello 5. Nello stesso istante viene deciso (in segreto) '
                    'quante evoluzioni avrà:',
                bullets: [
                  '~50% delle volte: UNA sola evoluzione, tra livello 40 e 50.',
                  '~50% delle volte: DUE evoluzioni, la prima tra livello 15 e '
                      '30, la seconda tra livello 55 e 75.',
                  'Il livello esatto non si scopre mai in anticipo: la '
                      'scheda della creatura mostra solo un indizio '
                      'approssimativo (es. "evolve presto" o "evolve tardi").',
                  'A ogni evoluzione la creatura guadagna un secondo tipo, '
                      'influenzato sia dal momento della cattura sia da meteo, '
                      'luogo e ora dell\'evoluzione stessa.',
                ],
              ),
              SizedBox(height: 20),
              _Section(
                icon: Icons.bolt,
                title: 'Livelli e mosse',
                body: 'Si sale di livello vincendo battaglie contro altri '
                    'animali fotografati, fino a un massimo di livello 100.',
                bullets: [
                  'Si parte con 4 mosse iniziali, tutte coerenti col tipo '
                      'della creatura.',
                  'Salendo di livello si sbloccano mosse più forti, da '
                      'scegliere se imparare al posto di una già conosciuta.',
                  'In battaglia, più indebolisci un animale selvatico (HP '
                      'bassi), più alta è la probabilità di catturarlo.',
                ],
              ),
              SizedBox(height: 20),
              _TypeChartSection(),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<String> bullets;

  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.rubyRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: AppFonts.pixelTitle(fontSize: 16, color: AppColors.panelBrown)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: AppFonts.body(fontSize: 15)),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(b, style: AppFonts.body(fontSize: 14))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabella di efficacia dei 12 tipi, generata da TypeChart.all: una
/// card per tipo con le sue debolezze/resistenze/immunità colorate,
/// così se cambia la tabella in type_chart.dart questa schermata si
/// aggiorna da sola, senza bisogno di tenerle sincronizzate a mano.
class _TypeChartSection extends StatelessWidget {
  const _TypeChartSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelCream,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, color: AppColors.sapphireBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tabella dei tipi',
                  style: AppFonts.pixelTitle(fontSize: 16, color: AppColors.panelBrown),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Per ogni tipo: contro cosa è debole (subisce 2x), cosa resiste '
            '(0.5x) e a cosa è immune (0x). Con due tipi, gli effetti si '
            'moltiplicano tra loro.',
            style: AppFonts.body(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          ...TypeChart.all.map((info) => _TypeMatchupCard(info: info)),
        ],
      ),
    );
  }
}

class _TypeMatchupCard extends StatelessWidget {
  final TypeMatchupInfo info;

  const _TypeMatchupCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TypeColors.of(info.type).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeBadge(type: info.type),
          const SizedBox(height: 8),
          _MatchupRow(label: 'Debole (2x)', types: info.weakTo, emptyDash: true),
          _MatchupRow(label: 'Resiste (0.5x)', types: info.resists, emptyDash: true),
          if (info.immuneTo.isNotEmpty) _MatchupRow(label: 'Immune', types: info.immuneTo),
        ],
      ),
    );
  }
}

class _MatchupRow extends StatelessWidget {
  final String label;
  final List<String> types;
  final bool emptyDash;

  const _MatchupRow({required this.label, required this.types, this.emptyDash = false});

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty && !emptyDash) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppFonts.body(fontSize: 12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: types.isEmpty
                ? Text('—', style: AppFonts.body(fontSize: 12, color: AppColors.textMuted))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: types.map((t) => _TypeBadge(type: t, small: true)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  final bool small;

  const _TypeBadge({required this.type, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = TypeColors.of(type);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        type.toUpperCase(),
        style: AppFonts.body(
          fontSize: small ? 11 : 13,
          color: Colors.white,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
