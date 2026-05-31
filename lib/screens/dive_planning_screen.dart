// lib/screens/dive_planning_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
// BÜHLMANN ZH-L16C
// 16 compartiments tissulaires — constantes officielles
// ═══════════════════════════════════════════════════════════════

class _Compartment {
  final double halfTimeN2; // min
  final double aN2; // bar
  final double bN2;
  final double halfTimeHe; // min
  final double aHe; // bar
  final double bHe;

  const _Compartment({
    required this.halfTimeN2,
    required this.aN2,
    required this.bN2,
    required this.halfTimeHe,
    required this.aHe,
    required this.bHe,
  });
}

const List<_Compartment> _zhl16c = [
  _Compartment(
      halfTimeN2: 4.0,
      aN2: 1.2599,
      bN2: 0.5050,
      halfTimeHe: 1.51,
      aHe: 1.7424,
      bHe: 0.4245),
  _Compartment(
      halfTimeN2: 8.0,
      aN2: 1.0000,
      bN2: 0.6514,
      halfTimeHe: 3.02,
      aHe: 1.3830,
      bHe: 0.5747),
  _Compartment(
      halfTimeN2: 12.5,
      aN2: 0.8618,
      bN2: 0.7222,
      halfTimeHe: 4.72,
      aHe: 1.1919,
      bHe: 0.6527),
  _Compartment(
      halfTimeN2: 18.5,
      aN2: 0.7562,
      bN2: 0.7725,
      halfTimeHe: 6.99,
      aHe: 1.0458,
      bHe: 0.7223),
  _Compartment(
      halfTimeN2: 27.0,
      aN2: 0.6200,
      bN2: 0.8125,
      halfTimeHe: 10.21,
      aHe: 0.9220,
      bHe: 0.7582),
  _Compartment(
      halfTimeN2: 38.3,
      aN2: 0.5043,
      bN2: 0.8434,
      halfTimeHe: 14.48,
      aHe: 0.8205,
      bHe: 0.7957),
  _Compartment(
      halfTimeN2: 54.3,
      aN2: 0.4410,
      bN2: 0.8693,
      halfTimeHe: 20.53,
      aHe: 0.7305,
      bHe: 0.8279),
  _Compartment(
      halfTimeN2: 77.0,
      aN2: 0.4000,
      bN2: 0.8910,
      halfTimeHe: 29.11,
      aHe: 0.6502,
      bHe: 0.8553),
  _Compartment(
      halfTimeN2: 109.0,
      aN2: 0.3750,
      bN2: 0.9092,
      halfTimeHe: 41.20,
      aHe: 0.5950,
      bHe: 0.8757),
  _Compartment(
      halfTimeN2: 146.0,
      aN2: 0.3500,
      bN2: 0.9222,
      halfTimeHe: 55.19,
      aHe: 0.5545,
      bHe: 0.8903),
  _Compartment(
      halfTimeN2: 187.0,
      aN2: 0.3295,
      bN2: 0.9319,
      halfTimeHe: 70.69,
      aHe: 0.5333,
      bHe: 0.8997),
  _Compartment(
      halfTimeN2: 239.0,
      aN2: 0.3065,
      bN2: 0.9403,
      halfTimeHe: 90.34,
      aHe: 0.5189,
      bHe: 0.9073),
  _Compartment(
      halfTimeN2: 305.0,
      aN2: 0.2835,
      bN2: 0.9477,
      halfTimeHe: 115.29,
      aHe: 0.5181,
      bHe: 0.9122),
  _Compartment(
      halfTimeN2: 390.0,
      aN2: 0.2610,
      bN2: 0.9544,
      halfTimeHe: 147.42,
      aHe: 0.5176,
      bHe: 0.9171),
  _Compartment(
      halfTimeN2: 498.0,
      aN2: 0.2480,
      bN2: 0.9602,
      halfTimeHe: 188.24,
      aHe: 0.5172,
      bHe: 0.9217),
  _Compartment(
      halfTimeN2: 635.0,
      aN2: 0.2327,
      bN2: 0.9653,
      halfTimeHe: 240.03,
      aHe: 0.5119,
      bHe: 0.9267),
];

// Pression d'eau douce vs mer — on utilise mer (10.1325 m/bar)
const double _mPerBar = 10.0;
// Pression vapeur d'eau alvéolaire
const double _pH2O = 0.0627; // bar
// Fraction N2 dans l'air alvéolaire au repos (surface)
const double _surfacePpN2 = (1.0 - _pH2O) * 0.79; // ≈ 0.7400 bar

// ─────────────────────────────────────────────
// Modèle Bühlmann : simulation compartiments
// ─────────────────────────────────────────────

class BuhlmannEngine {
  // Saturation initiale à la surface (air)
  List<double> _ppN2 = List.filled(16, _surfacePpN2);
  List<double> _ppHe = List.filled(16, 0.0);

  BuhlmannEngine();

  // Clone de l'état courant
  BuhlmannEngine._clone(List<double> n2, List<double> he)
      : _ppN2 = List.of(n2),
        _ppHe = List.of(he);

  BuhlmannEngine clone() => BuhlmannEngine._clone(_ppN2, _ppHe);

  // Exposition à une pression ambiante pendant [minutes] minutes
  void expose({
    required double ambientBar, // pression ambiante en bar
    required double fn2, // fraction N2 du gaz
    required double fhe, // fraction He du gaz (0 pour Nitrox/Air)
    required double minutes,
  }) {
    final inspiredN2 = (ambientBar - _pH2O) * fn2;
    final inspiredHe = (ambientBar - _pH2O) * fhe;

    for (int i = 0; i < 16; i++) {
      final c = _zhl16c[i];
      final kN2 = log(2) / c.halfTimeN2;
      final kHe = log(2) / c.halfTimeHe;
      _ppN2[i] += (inspiredN2 - _ppN2[i]) * (1 - exp(-kN2 * minutes));
      _ppHe[i] += (inspiredHe - _ppHe[i]) * (1 - exp(-kHe * minutes));
    }
  }

  // Pression de seuil de tolérance (M-value) à une pression ambiante donnée
  // Retourne la pression de gaz inerte max tolérée dans chaque compartiment
  double ceilingBar() {
    double ceiling = 0.0;
    for (int i = 0; i < 16; i++) {
      final c = _zhl16c[i];
      // a et b mixés He/N2
      final totalPpInert = _ppN2[i] + _ppHe[i];
      if (totalPpInert <= 0) continue;
      final fracHe = _ppHe[i] / totalPpInert;
      final fracN2 = 1.0 - fracHe;
      final a = fracN2 * c.aN2 + fracHe * c.aHe;
      final b = fracN2 * c.bN2 + fracHe * c.bHe;
      // Plafond minimum pour ce compartiment
      final pMin = (totalPpInert - a) * b;
      if (pMin > ceiling) ceiling = pMin;
    }
    return ceiling;
  }

  // Profondeur plafond en mètres (0 = pas de palier)
  double ceilingMeters() {
    final ceil = ceilingBar();
    if (ceil <= 1.0) return 0.0;
    return ((ceil - 1.0) * _mPerBar);
  }

  // Profondeur de palier arrondie à 3 m supérieurs
  int stopDepthMeters() {
    final ceil = ceilingMeters();
    if (ceil <= 0) return 0;
    return (((ceil / 3.0).ceil()) * 3).toInt();
  }
}

// ─────────────────────────────────────────────
// Calcul plan complet avec Bühlmann
// ─────────────────────────────────────────────

class DecoStop {
  final int depth; // m
  final int duration; // min
  const DecoStop({required this.depth, required this.duration});
}

class BuhlmannResult {
  final List<DecoStop> stops;
  final int dtr; // durée totale de remontée (min) paliers inclus
  final bool ndl; // true = sans décompression
  final int ndlMinutes; // limite sans déco restante à ce profil (si ndl)
  final double maxSaturation; // % saturation max compartiment critique
  final int tts; // Time To Surface (min)

  const BuhlmannResult({
    required this.stops,
    required this.dtr,
    required this.ndl,
    required this.ndlMinutes,
    required this.maxSaturation,
    required this.tts,
  });
}

const double _ascentRate = 9.0; // m/min
const double _descentRate = 20.0; // m/min

BuhlmannResult computeBuhlmann({
  required double depth, // m
  required int bottomTime, // min
  required GazMixture gas,
}) {
  final engine = BuhlmannEngine();
  final ambientBottom = depth / _mPerBar + 1.0;

  // 1. Descente
  final descentMin = depth / _descentRate;
  // Pression moyenne pendant la descente
  for (int step = 0; step < (descentMin * 10).round(); step++) {
    final frac = step / (descentMin * 10);
    final p = 1.0 + (depth * frac) / _mPerBar;
    engine.expose(ambientBar: p, fn2: gas.fn2, fhe: 0, minutes: 0.1);
  }

  // 2. Fond
  engine.expose(
    ambientBar: ambientBottom,
    fn2: gas.fn2,
    fhe: 0,
    minutes: bottomTime.toDouble(),
  );

  // Calcul saturation max (pour affichage)
  double maxSat = 0;
  for (int i = 0; i < 16; i++) {
    final c = _zhl16c[i];
    final totalInert = engine._ppN2[i] + engine._ppHe[i];
    final mVal = c.aN2 + ambientBottom / c.bN2;
    final sat = totalInert / mVal;
    if (sat > maxSat) maxSat = sat;
  }

  // 3. Calcul NDL (pour info — combien de minutes supplémentaires possibles)
  int ndlMinutes = 0;
  {
    final testEngine = engine.clone();
    while (ndlMinutes < 999) {
      testEngine.expose(
          ambientBar: ambientBottom, fn2: gas.fn2, fhe: 0, minutes: 1);
      ndlMinutes++;
      // Simuler remontée directe depuis ce point
      final testEngine2 = testEngine.clone();
      final ceil = _simulateDirectAscent(testEngine2, depth, gas);
      if (ceil > 0) break;
    }
  }

  // 4. Remontée avec paliers
  final stops = <DecoStop>[];
  int dtr = 0;
  double currentDepth = depth;
  final ascentEngine = engine.clone();

  while (currentDepth > 0) {
    final stopDepth = ascentEngine.stopDepthMeters();

    if (stopDepth <= 0) {
      // Remontée libre jusqu'à surface
      final tMin = currentDepth / _ascentRate;
      for (int step = 0; step < (tMin * 10).round(); step++) {
        final frac = step / (tMin * 10);
        final p = (1.0 + currentDepth / _mPerBar) * (1 - frac) + 1.0 * frac;
        ascentEngine.expose(ambientBar: p, fn2: gas.fn2, fhe: 0, minutes: 0.1);
      }
      dtr += tMin.ceil();
      break;
    }

    // Remonter jusqu'au prochain palier
    if (stopDepth < currentDepth) {
      final travelMin = (currentDepth - stopDepth) / _ascentRate;
      for (int step = 0; step < (travelMin * 10).round(); step++) {
        final frac = step / (travelMin * 10);
        final p = (1.0 + currentDepth / _mPerBar) * (1 - frac) +
            (1.0 + stopDepth / _mPerBar) * frac;
        ascentEngine.expose(ambientBar: p, fn2: gas.fn2, fhe: 0, minutes: 0.1);
      }
      dtr += travelMin.ceil();
      currentDepth = stopDepth.toDouble();
    }

    // Tenir le palier minute par minute
    int stopDuration = 0;
    while (ascentEngine.stopDepthMeters() >= stopDepth && stopDuration < 120) {
      ascentEngine.expose(
          ambientBar: 1.0 + currentDepth / _mPerBar,
          fn2: gas.fn2,
          fhe: 0,
          minutes: 1);
      stopDuration++;
      dtr++;
    }

    if (stopDuration > 0) {
      stops.add(DecoStop(depth: stopDepth, duration: stopDuration));
    }

    // Remonter de 3 m
    currentDepth = (currentDepth - 3).clamp(0, double.infinity);
  }

  final ndl = stops.isEmpty;
  final tts = dtr;

  return BuhlmannResult(
    stops: stops,
    dtr: dtr,
    ndl: ndl,
    ndlMinutes: ndlMinutes,
    maxSaturation: maxSat,
    tts: tts,
  );
}

// Simule une remontée directe et retourne le plafond max rencontré
double _simulateDirectAscent(
    BuhlmannEngine engine, double depth, GazMixture gas) {
  double maxCeil = 0;
  double current = depth;
  while (current > 0) {
    final next = (current - 3).clamp(0, double.infinity);
    final travelMin = (current - next) / _ascentRate;
    for (int s = 0; s < (travelMin * 10).round(); s++) {
      final frac = s / (travelMin * 10);
      final p = (1.0 + current / _mPerBar) * (1 - frac) +
          (1.0 + next / _mPerBar) * frac;
      engine.expose(ambientBar: p, fn2: gas.fn2, fhe: 0, minutes: 0.1);
    }
    final c = engine.ceilingMeters();
    if (c > maxCeil) maxCeil = c;
    current = next;
  }
  return maxCeil;
}

// ═══════════════════════════════════════════════════════════════
// Modèles gaz & données
// ═══════════════════════════════════════════════════════════════

class GazMixture {
  final String name;
  final String label;
  final double fo2;
  final double fn2;
  final String icon;
  final Color color;

  const GazMixture({
    required this.name,
    required this.label,
    required this.fo2,
    required this.fn2,
    required this.icon,
    required this.color,
  });

  double get modMeters =>
      fo2 > 0 ? (1.4 / fo2 - 1) * _mPerBar : double.infinity;
  double endAtDepth(double depth) =>
      ((depth / _mPerBar + 1) * fn2 / 0.79 - 1) * _mPerBar;
}

const List<GazMixture> gasMixtures = [
  GazMixture(
      name: 'air',
      label: 'Air',
      fo2: 0.21,
      fn2: 0.79,
      icon: '💨',
      color: Color(0xFF1565C0)),
  GazMixture(
      name: 'nitrox32',
      label: 'Nitrox 32%',
      fo2: 0.32,
      fn2: 0.68,
      icon: '🟢',
      color: Color(0xFF2E7D32)),
  GazMixture(
      name: 'nitrox36',
      label: 'Nitrox 36%',
      fo2: 0.36,
      fn2: 0.64,
      icon: '🟡',
      color: Color(0xFFF57F17)),
  GazMixture(
      name: 'nitrox40',
      label: 'Nitrox 40%',
      fo2: 0.40,
      fn2: 0.60,
      icon: '🟠',
      color: Color(0xFFE65100)),
];

// ═══════════════════════════════════════════════════════════════
// Calcul consommation gaz
// ═══════════════════════════════════════════════════════════════

class DivePlanResult {
  final double pressureAtDepth;
  final double volumeAtDepth;
  final double totalVolumeConsumed;
  final double totalPressureConsumed;
  final double reservePressure;
  final bool hasEnoughGas;
  final double autonomyMinutes;
  final bool exceedsMOD;
  final double mod;
  final double end;
  final BuhlmannResult buhlmann;

  const DivePlanResult({
    required this.pressureAtDepth,
    required this.volumeAtDepth,
    required this.totalVolumeConsumed,
    required this.totalPressureConsumed,
    required this.reservePressure,
    required this.hasEnoughGas,
    required this.autonomyMinutes,
    required this.exceedsMOD,
    required this.mod,
    required this.end,
    required this.buhlmann,
  });
}

DivePlanResult computeDivePlan({
  required int bottleVolume,
  required int chargePressure,
  required double depth,
  required int divingTime,
  required GazMixture gas,
  required double conso,
}) {
  const reserveBar = 50.0;
  final pressureAtDepth = depth / _mPerBar + 1.0;
  final volumeAtDepth = conso * pressureAtDepth;

  final ascentTime = depth / _ascentRate;
  final avgAscentPressure = (pressureAtDepth + 1) / 2;
  final totalVolumeConsumed = conso * pressureAtDepth * divingTime +
      conso * avgAscentPressure * ascentTime;

  final totalCapacity = bottleVolume.toDouble() * chargePressure.toDouble();
  final reserveVolume = bottleVolume * reserveBar;
  final usableVolume = totalCapacity - reserveVolume;

  final totalPressureConsumed = totalVolumeConsumed / bottleVolume;
  final hasEnoughGas = totalVolumeConsumed <= usableVolume;
  final autonomyMinutes = usableVolume / volumeAtDepth;

  final mod = gas.modMeters;
  final exceedsMOD = depth > mod;
  final end = gas.endAtDepth(depth);

  final buhlmann = computeBuhlmann(
    depth: depth,
    bottomTime: divingTime,
    gas: gas,
  );

  return DivePlanResult(
    pressureAtDepth: pressureAtDepth,
    volumeAtDepth: volumeAtDepth,
    totalVolumeConsumed: totalVolumeConsumed,
    totalPressureConsumed: totalPressureConsumed,
    reservePressure: reserveBar,
    hasEnoughGas: hasEnoughGas,
    autonomyMinutes: autonomyMinutes,
    exceedsMOD: exceedsMOD,
    mod: mod,
    end: end,
    buhlmann: buhlmann,
  );
}

// ═══════════════════════════════════════════════════════════════
// Écran principal
// ═══════════════════════════════════════════════════════════════

class DivePlanningScreen extends StatefulWidget {
  const DivePlanningScreen({super.key});

  @override
  State<DivePlanningScreen> createState() => _DivePlanningScreenState();
}

class _DivePlanningScreenState extends State<DivePlanningScreen>
    with SingleTickerProviderStateMixin {
  int _bottleVolume = 12;
  int _chargePressure = 200;
  double _depth = 20;
  int _divingTime = 30;
  GazMixture _selectedGas = gasMixtures[0];
  double _conso = 20;

  late AnimationController _resultAnim;
  late Animation<double> _fadeAnim;

  DivePlanResult? _result;

  final _depthController = TextEditingController(text: '20');
  final _timeController = TextEditingController(text: '30');
  final _consoController = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _compute();
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    _depthController.dispose();
    _timeController.dispose();
    _consoController.dispose();
    super.dispose();
  }

  void _compute() {
    setState(() {
      _result = computeDivePlan(
        bottleVolume: _bottleVolume,
        chargePressure: _chargePressure,
        depth: _depth,
        divingTime: _divingTime,
        gas: _selectedGas,
        conso: _conso,
      );
    });
    _resultAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006064),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🧭', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Planification de Plongée'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildParametersCard(),
            const SizedBox(height: 16),
            _buildGasSelector(),
            const SizedBox(height: 16),
            _buildComputeButton(),
            const SizedBox(height: 20),
            if (_result != null)
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    if (_result!.exceedsMOD) ...[
                      _buildWarningBanner(),
                      const SizedBox(height: 8),
                    ],
                    _buildGasCard(),
                    const SizedBox(height: 16),
                    _buildBuhlmannCard(),
                    const SizedBox(height: 16),
                    _buildSafetyCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Paramètres ───

  Widget _buildParametersCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: '⚙️', title: 'Paramètres de plongée'),
          const SizedBox(height: 16),
          const _Label('Volume de bouteille'),
          const SizedBox(height: 8),
          Row(
            children: [10, 12, 15].map((vol) {
              final sel = _bottleVolume == vol;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _bottleVolume = vol);
                      _compute();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF006064) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF006064)
                              : const Color(0xFFCFD8DC),
                          width: sel ? 2 : 1,
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF006064)
                                        .withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3))
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Text('$vol L',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFF37474F))),
                          Text(
                              vol == 10
                                  ? 'Compact'
                                  : vol == 12
                                      ? 'Standard'
                                      : 'Grande',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: sel
                                      ? Colors.white70
                                      : const Color(0xFF78909C))),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const _Label('Pression de charge (bar)'),
          const SizedBox(height: 8),
          Row(
            children: [150, 200, 232, 300].map((p) {
              final sel = _chargePressure == p;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _chargePressure = p);
                      _compute();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFF00838F) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel
                                ? const Color(0xFF00838F)
                                : const Color(0xFFCFD8DC)),
                      ),
                      child: Text('$p',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF455A64))),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Profondeur (m)'),
                    const SizedBox(height: 8),
                    _NumberInput(
                      controller: _depthController,
                      hint: 'Ex: 20',
                      suffix: 'm',
                      onChanged: (v) {
                        final d = double.tryParse(v);
                        if (d != null && d > 0 && d <= 60) {
                          _depth = d;
                          _compute();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('Temps fond (min)'),
                    const SizedBox(height: 8),
                    _NumberInput(
                      controller: _timeController,
                      hint: 'Ex: 30',
                      suffix: 'min',
                      onChanged: (v) {
                        final t = int.tryParse(v);
                        if (t != null && t > 0) {
                          _divingTime = t;
                          _compute();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Consommation surface (L/min)'),
          const SizedBox(height: 4),
          const Text('Débutant ≈ 25 · Confirmé ≈ 20 · Expert ≈ 15',
              style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _conso,
                  min: 10,
                  max: 40,
                  divisions: 30,
                  activeColor: const Color(0xFF006064),
                  label: '${_conso.round()} L/min',
                  onChanged: (v) {
                    setState(() {
                      _conso = v;
                      _consoController.text = v.round().toString();
                    });
                    _compute();
                  },
                ),
              ),
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFF006064).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${_conso.round()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006064),
                        fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Sélecteur gaz ───

  Widget _buildGasSelector() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: '🫁', title: 'Gaz de plongée'),
          const SizedBox(height: 12),
          ...gasMixtures.map((gas) {
            final sel = _selectedGas.name == gas.name;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedGas = gas);
                _compute();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? gas.color.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel ? gas.color : const Color(0xFFCFD8DC),
                      width: sel ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Text(gas.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gas.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: sel
                                      ? gas.color
                                      : const Color(0xFF37474F))),
                          Text(
                              'O₂: ${(gas.fo2 * 100).round()}%  ·  N₂: ${(gas.fn2 * 100).round()}%  ·  MOD: ${gas.modMeters.isInfinite ? "∞" : "${gas.modMeters.round()} m"}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF78909C))),
                        ],
                      ),
                    ),
                    if (sel)
                      Icon(Icons.check_circle, color: gas.color, size: 22),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComputeButton() {
    return ElevatedButton.icon(
      onPressed: _compute,
      icon: const Icon(Icons.calculate_outlined),
      label: const Text('Calculer le plan de plongée'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006064),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Text('⛔', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Profondeur hors limite MOD !\nMOD du ${_selectedGas.label} : ${_result!.mod.round()} m. Risque d\'hyperoxie (ppO₂ > 1,4 bar).',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Carte consommation gaz ───

  Widget _buildGasCard() {
    final r = _result!;
    final totalCap = _bottleVolume * _chargePressure;
    final usedPct = (r.totalVolumeConsumed / totalCap).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: '🔋', title: 'Consommation de gaz'),
          const SizedBox(height: 16),
          _GaugeRow(
              label: 'Pression absolue fond',
              value: '${r.pressureAtDepth.toStringAsFixed(1)} bar',
              color: const Color(0xFF0288D1)),
          _GaugeRow(
              label: 'Débit au fond',
              value: '${r.volumeAtDepth.toStringAsFixed(1)} L/min',
              color: const Color(0xFF00838F)),
          _GaugeRow(
              label: 'Volume consommé total',
              value: '${r.totalVolumeConsumed.toStringAsFixed(0)} L',
              color: r.hasEnoughGas
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828)),
          _GaugeRow(
              label: 'Pression consommée',
              value: '${r.totalPressureConsumed.toStringAsFixed(0)} bar',
              color: r.hasEnoughGas
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Capacité utilisée',
                  style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
              Text('${(usedPct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: usedPct > 0.8
                          ? const Color(0xFFC62828)
                          : const Color(0xFF006064))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: usedPct,
              minHeight: 12,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation(usedPct > 0.85
                  ? const Color(0xFFC62828)
                  : usedPct > 0.65
                      ? const Color(0xFFF57F17)
                      : const Color(0xFF006064)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _InfoTile(
                      icon: '⛽',
                      label: 'Réserve',
                      value: '${r.reservePressure.round()} bar',
                      subtitle:
                          '${(_bottleVolume * r.reservePressure).round()} L',
                      color: const Color(0xFFFF6F00))),
              const SizedBox(width: 12),
              Expanded(
                  child: _InfoTile(
                      icon: '⏱️',
                      label: 'Autonomie fond',
                      value: '${r.autonomyMinutes.toStringAsFixed(0)} min',
                      subtitle: 'hors réserve',
                      color: const Color(0xFF1565C0))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: r.hasEnoughGas
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: r.hasEnoughGas
                      ? const Color(0xFF81C784)
                      : const Color(0xFFEF9A9A)),
            ),
            child: Row(
              children: [
                Text(r.hasEnoughGas ? '✅' : '⚠️',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.hasEnoughGas
                        ? 'Gaz suffisant (réserve ${r.reservePressure.round()} bar conservée)'
                        : 'Gaz insuffisant ! Réduisez la profondeur ou le temps.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: r.hasEnoughGas
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Carte Bühlmann ───

  Widget _buildBuhlmannCard() {
    final bh = _result!.buhlmann;
    final satPct = (bh.maxSaturation * 100).clamp(0, 200).toDouble();
    final satColor = satPct >= 100
        ? const Color(0xFFC62828)
        : satPct >= 80
            ? const Color(0xFFF57F17)
            : const Color(0xFF2E7D32);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
              icon: '🫧', title: 'Désaturation — Bühlmann ZH-L16C'),
          const SizedBox(height: 16),

          // Stats principales
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF006064), Color(0xFF00838F)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DTRStat(icon: '⏱️', value: '${bh.tts} min', label: 'TTS'),
                Container(width: 1, height: 50, color: Colors.white24),
                _DTRStat(
                  icon: bh.ndl ? '🟢' : '🔴',
                  value: bh.ndl ? 'NDL' : 'DÉCO',
                  label: bh.ndl ? 'Sans palier' : 'Avec palier',
                ),
                Container(width: 1, height: 50, color: Colors.white24),
                _DTRStat(
                  icon: '🫁',
                  value: '${satPct.toStringAsFixed(0)}%',
                  label: 'Saturation',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // NDL restant ou paliers
          if (bh.ndl) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                children: [
                  const Text('✅', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Plongée sans décompression obligatoire',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32))),
                        Text(
                            'Durée sans déco restante estimée : ${bh.ndlMinutes} min supplémentaires',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF388E3C))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('Paliers de décompression',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF37474F))),
            const SizedBox(height: 10),
            ...bh.stops
                .map((s) => _PalierRow(depth: s.depth, duration: s.duration)),
          ],

          const SizedBox(height: 12),

          // Barre saturation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saturation compartiment critique',
                      style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
                  Text('${satPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: satColor)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (satPct / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation(satColor),
                ),
              ),
              const SizedBox(height: 4),
              const Text('100% = M-value atteinte (limite de décompression)',
                  style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(
              children: [
                Icon(Icons.arrow_upward, color: Color(0xFF006064), size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Vitesse de remontée : 9 m/min max · GF 100/100 (ZH-L16C conservateur)',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF00838F),
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sécurité ───

  Widget _buildSafetyCard() {
    final r = _result!;
    final ppO2 = r.pressureAtDepth * _selectedGas.fo2;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: '🛡️', title: 'Sécurité & Narcose'),
          const SizedBox(height: 14),
          _GaugeRow(
              label: 'END (profondeur narcotique équiv. air)',
              value: '${r.end.toStringAsFixed(1)} m',
              color: r.end > 30
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32)),
          _GaugeRow(
              label: 'ppO₂ au fond',
              value: '${ppO2.toStringAsFixed(2)} bar',
              color: ppO2 > 1.4
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32)),
          _GaugeRow(
              label: 'MOD (${_selectedGas.label})',
              value: r.mod.isInfinite ? '∞' : '${r.mod.round()} m',
              color: const Color(0xFF1565C0)),
          const SizedBox(height: 12),
          const _SafetyNote(
              icon: '📌',
              text:
                  'Palier de sécurité conseillé : 3 min à 3 m (non inclus dans le TTS Bühlmann).'),
          const SizedBox(height: 6),
          const _SafetyNote(
              icon: '📌',
              text: 'Règle du tiers : 1/3 aller · 1/3 retour · 1/3 réserve.'),
          const SizedBox(height: 6),
          const _SafetyNote(
              icon: '⚠️',
              text:
                  'Ce calcul est indicatif. Toujours plonger avec un ordinateur de plongée homologué.'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Widgets réutilisables
// ═══════════════════════════════════════════════════════════════

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF006064))),
        ],
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF455A64)));
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint, suffix;
  final ValueChanged<String> onChanged;
  const _NumberInput(
      {required this.controller,
      required this.hint,
      required this.suffix,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        decoration: InputDecoration(
          hintText: hint,
          suffixText: suffix,
          suffixStyle: const TextStyle(
              color: Color(0xFF006064), fontWeight: FontWeight.bold),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCFD8DC))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064), width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: onChanged,
      );
}

class _GaugeRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _GaugeRow(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final String icon, label, value, subtitle;
  final Color color;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.subtitle,
      required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A))),
            Text(subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
          ],
        ),
      );
}

class _DTRStat extends StatelessWidget {
  final String icon, value, label;
  const _DTRStat(
      {required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}

class _PalierRow extends StatelessWidget {
  final int depth, duration;
  const _PalierRow({required this.depth, required this.duration});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2F1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF80CBC4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.pause_circle_outline,
                color: Color(0xFF006064), size: 20),
            const SizedBox(width: 10),
            Text('Palier à $depth m',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF006064))),
            const Spacer(),
            Text('$duration min',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                    fontSize: 15)),
          ],
        ),
      );
}

class _SafetyNote extends StatelessWidget {
  final String icon, text;
  const _SafetyNote({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF546E7A)))),
        ],
      );
}
