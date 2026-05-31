// lib/screens/dive_planning_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
// Modèles de données
// ─────────────────────────────────────────────

class GazMixture {
  final String name;
  final String label;
  final double fo2; // fraction O2
  final double fn2; // fraction N2
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

  double get ppO2Max => fo2 > 0 ? 1.4 / fo2 - 1 : double.infinity; // profondeur max MOD (bar)
  double get modMeters => fo2 > 0 ? (1.4 / fo2 - 1) * 10 : double.infinity;
  double get endAtDepth(double depth) => (depth / 10 + 1) * fn2 / 0.79 * 10 - 10;
}

const List<GazMixture> gasMixtures = [
  GazMixture(
    name: 'air',
    label: 'Air',
    fo2: 0.21,
    fn2: 0.79,
    icon: '💨',
    color: Color(0xFF1565C0),
  ),
  GazMixture(
    name: 'nitrox32',
    label: 'Nitrox 32%',
    fo2: 0.32,
    fn2: 0.68,
    icon: '🟢',
    color: Color(0xFF2E7D32),
  ),
  GazMixture(
    name: 'nitrox36',
    label: 'Nitrox 36%',
    fo2: 0.36,
    fn2: 0.64,
    icon: '🟡',
    color: Color(0xFFF57F17),
  ),
  GazMixture(
    name: 'nitrox40',
    label: 'Nitrox 40%',
    fo2: 0.40,
    fn2: 0.60,
    icon: '🟠',
    color: Color(0xFFE65100),
  ),
];

// ─────────────────────────────────────────────
// Modèle MN90 simplifié — paliers DTR
// La table MN90 officielle pour les cas courants
// ─────────────────────────────────────────────

class DiveProfile {
  final int depth;      // profondeur en m
  final int time;       // temps fond en min
  final List<DecoStop> stops;
  final int dtr;        // durée totale de remontée (min)
  final String group;   // groupe de désaturation

  const DiveProfile({
    required this.depth,
    required this.time,
    required this.stops,
    required this.dtr,
    required this.group,
  });
}

class DecoStop {
  final int depth;
  final int duration;
  const DecoStop({required this.depth, required this.duration});
}

// Table MN90 simplifiée (profondeur → [(temps, paliers, dtr, groupe)])
// paliers format : liste de {depth: x, dur: y}
final Map<int, List<Map<String, dynamic>>> _mn90Table = {
  10: [
    {'t': 20, 'stops': [], 'dtr': 2, 'g': 'A'},
    {'t': 40, 'stops': [], 'dtr': 2, 'g': 'B'},
    {'t': 60, 'stops': [], 'dtr': 2, 'g': 'C'},
    {'t': 120, 'stops': [], 'dtr': 2, 'g': 'D'},
    {'t': 180, 'stops': [], 'dtr': 2, 'g': 'E'},
  ],
  15: [
    {'t': 20, 'stops': [], 'dtr': 3, 'g': 'A'},
    {'t': 40, 'stops': [], 'dtr': 3, 'g': 'B'},
    {'t': 60, 'stops': [], 'dtr': 3, 'g': 'C'},
    {'t': 90, 'stops': [], 'dtr': 3, 'g': 'D'},
    {'t': 120, 'stops': [{'d': 3, 'dur': 3}], 'dtr': 6, 'g': 'E'},
  ],
  20: [
    {'t': 20, 'stops': [], 'dtr': 4, 'g': 'A'},
    {'t': 35, 'stops': [], 'dtr': 4, 'g': 'B'},
    {'t': 45, 'stops': [], 'dtr': 4, 'g': 'C'},
    {'t': 55, 'stops': [{'d': 3, 'dur': 5}], 'dtr': 9, 'g': 'D'},
    {'t': 70, 'stops': [{'d': 3, 'dur': 15}], 'dtr': 19, 'g': 'E'},
  ],
  25: [
    {'t': 15, 'stops': [], 'dtr': 5, 'g': 'A'},
    {'t': 25, 'stops': [], 'dtr': 5, 'g': 'B'},
    {'t': 35, 'stops': [{'d': 3, 'dur': 5}], 'dtr': 10, 'g': 'C'},
    {'t': 45, 'stops': [{'d': 3, 'dur': 15}], 'dtr': 20, 'g': 'D'},
    {'t': 55, 'stops': [{'d': 6, 'dur': 5}, {'d': 3, 'dur': 25}], 'dtr': 35, 'g': 'E'},
  ],
  30: [
    {'t': 10, 'stops': [], 'dtr': 6, 'g': 'A'},
    {'t': 20, 'stops': [], 'dtr': 6, 'g': 'B'},
    {'t': 25, 'stops': [{'d': 3, 'dur': 5}], 'dtr': 11, 'g': 'C'},
    {'t': 30, 'stops': [{'d': 3, 'dur': 15}], 'dtr': 21, 'g': 'D'},
    {'t': 40, 'stops': [{'d': 6, 'dur': 5}, {'d': 3, 'dur': 25}], 'dtr': 36, 'g': 'E'},
  ],
  35: [
    {'t': 10, 'stops': [], 'dtr': 7, 'g': 'A'},
    {'t': 15, 'stops': [], 'dtr': 7, 'g': 'B'},
    {'t': 20, 'stops': [{'d': 3, 'dur': 5}], 'dtr': 12, 'g': 'C'},
    {'t': 25, 'stops': [{'d': 6, 'dur': 5}, {'d': 3, 'dur': 15}], 'dtr': 27, 'g': 'D'},
    {'t': 30, 'stops': [{'d': 9, 'dur': 5}, {'d': 6, 'dur': 10}, {'d': 3, 'dur': 20}], 'dtr': 42, 'g': 'E'},
  ],
  40: [
    {'t': 5, 'stops': [], 'dtr': 8, 'g': 'A'},
    {'t': 10, 'stops': [], 'dtr': 8, 'g': 'B'},
    {'t': 15, 'stops': [{'d': 3, 'dur': 5}], 'dtr': 13, 'g': 'C'},
    {'t': 20, 'stops': [{'d': 6, 'dur': 5}, {'d': 3, 'dur': 15}], 'dtr': 28, 'g': 'D'},
    {'t': 25, 'stops': [{'d': 9, 'dur': 5}, {'d': 6, 'dur': 10}, {'d': 3, 'dur': 25}], 'dtr': 47, 'g': 'E'},
  ],
};

Map<String, dynamic>? _lookupMN90(int depth, int time) {
  // Arrondi à la profondeur standard supérieure
  final depths = _mn90Table.keys.toList()..sort();
  int? tableDepth;
  for (final d in depths) {
    if (depth <= d) {
      tableDepth = d;
      break;
    }
  }
  if (tableDepth == null) return null;

  final rows = _mn90Table[tableDepth]!;
  for (final row in rows) {
    if (time <= (row['t'] as int)) return row;
  }
  // Dépasse la table → hors table
  return null;
}

// ─────────────────────────────────────────────
// Calculs de consommation
// ─────────────────────────────────────────────

class DivePlanResult {
  final double pressureAtDepth;      // bar
  final double volumeAtDepth;        // L/min au fond
  final double totalVolumeConsumed;  // L totaux
  final double totalPressureConsumed; // bar
  final double reservePressure;      // bar (réserve 50 bar)
  final double usablePressure;       // bar disponible hors réserve
  final bool hasEnoughGas;
  final double autonomyMinutes;      // autonomie totale en min
  final Map<String, dynamic>? mn90;
  final bool outOfTable;
  final bool exceedsMOD;
  final double mod;
  final double end; // equivalent narcotic depth (air équivalent)

  const DivePlanResult({
    required this.pressureAtDepth,
    required this.volumeAtDepth,
    required this.totalVolumeConsumed,
    required this.totalPressureConsumed,
    required this.reservePressure,
    required this.usablePressure,
    required this.hasEnoughGas,
    required this.autonomyMinutes,
    required this.mn90,
    required this.outOfTable,
    required this.exceedsMOD,
    required this.mod,
    required this.end,
  });
}

DivePlanResult computeDivePlan({
  required int bottleVolume,       // L
  required int chargePressure,     // bar (pression de charge)
  required double depth,           // m
  required int divingTime,         // min
  required GazMixture gas,
  required double conso,           // L/min surface (consommation plongeur)
}) {
  const reserveBar = 50.0;

  final pressureAtDepth = depth / 10 + 1; // bar absolus
  final volumeAtDepth = conso * pressureAtDepth; // L/min au fond

  // Consommation totale (simplifiée : fond + remontée à 9 m/min)
  final ascentTime = depth / 9; // min remontée directe sans palier
  final avgAscentPressure = (pressureAtDepth + 1) / 2;
  final ascentVolume = conso * avgAscentPressure * ascentTime;
  final bottomVolume = conso * pressureAtDepth * divingTime;
  final totalVolumeConsumed = bottomVolume + ascentVolume;

  final totalCapacity = bottleVolume.toDouble() * chargePressure.toDouble();
  final reserveVolume = bottleVolume * reserveBar;
  final usableVolume = totalCapacity - reserveVolume;

  final totalPressureConsumed = totalVolumeConsumed / bottleVolume;
  final usablePressure = chargePressure - reserveBar;
  final hasEnoughGas = totalVolumeConsumed <= usableVolume;
  final autonomyMinutes = usableVolume / volumeAtDepth;

  // MN90
  final mn90 = _lookupMN90(depth.toInt(), divingTime);
  final outOfTable = mn90 == null && depth <= 40;

  // MOD (Maximum Operating Depth)
  final mod = gas.modMeters;
  final exceedsMOD = depth > mod;

  // END (Equivalent Narcotic Depth) — profondeur narcotique équivalente air
  final end = (pressureAtDepth * gas.fn2 / 0.79 - 1) * 10;

  return DivePlanResult(
    pressureAtDepth: pressureAtDepth,
    volumeAtDepth: volumeAtDepth,
    totalVolumeConsumed: totalVolumeConsumed,
    totalPressureConsumed: totalPressureConsumed,
    reservePressure: reserveBar,
    usablePressure: usablePressure,
    hasEnoughGas: hasEnoughGas,
    autonomyMinutes: autonomyMinutes,
    mn90: mn90,
    outOfTable: outOfTable,
    exceedsMOD: exceedsMOD,
    mod: mod,
    end: end,
  );
}

// ─────────────────────────────────────────────
// Écran principal
// ─────────────────────────────────────────────

class DivePlanningScreen extends StatefulWidget {
  const DivePlanningScreen({super.key});

  @override
  State<DivePlanningScreen> createState() => _DivePlanningScreenState();
}

class _DivePlanningScreenState extends State<DivePlanningScreen>
    with SingleTickerProviderStateMixin {
  // Paramètres
  int _bottleVolume = 12;
  int _chargePressure = 200;
  double _depth = 20;
  int _divingTime = 30;
  GazMixture _selectedGas = gasMixtures[0];
  double _conso = 20; // L/min surface par défaut

  late AnimationController _resultAnim;
  late Animation<double> _fadeAnim;

  DivePlanResult? _result;

  final _depthController = TextEditingController(text: '20');
  final _timeController = TextEditingController(text: '30');
  final _consoController = TextEditingController(text: '20');
  final _pressureController = TextEditingController(text: '200');

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _resultAnim, curve: Curves.easeOut);
    _compute();
  }

  @override
  void dispose() {
    _resultAnim.dispose();
    _depthController.dispose();
    _timeController.dispose();
    _consoController.dispose();
    _pressureController.dispose();
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
            if (_result != null) ...[
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    if (_result!.exceedsMOD) _buildWarningBanner(),
                    const SizedBox(height: 8),
                    _buildGasConsumptionCard(),
                    const SizedBox(height: 16),
                    _buildDTRCard(),
                    const SizedBox(height: 16),
                    _buildSafetyCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Carte paramètres ───

  Widget _buildParametersCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '⚙️', title: 'Paramètres de plongée'),
          const SizedBox(height: 16),

          // Bouteille
          _Label('Volume de bouteille'),
          const SizedBox(height: 8),
          Row(
            children: [10, 12, 15].map((vol) {
              final selected = _bottleVolume == vol;
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
                        color: selected
                            ? const Color(0xFF006064)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF006064)
                              : const Color(0xFFCFD8DC),
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF006064).withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$vol L',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: selected ? Colors.white : const Color(0xFF37474F),
                            ),
                          ),
                          Text(
                            vol == 10 ? 'Compact' : vol == 12 ? 'Standard' : 'Grande',
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white70
                                  : const Color(0xFF78909C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Pression de charge
          _Label('Pression de charge (bar)'),
          const SizedBox(height: 8),
          Row(
            children: [150, 200, 232, 300].map((p) {
              final selected = _chargePressure == p;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _chargePressure = p);
                      _pressureController.text = '$p';
                      _compute();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF00838F)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF00838F)
                              : const Color(0xFFCFD8DC),
                        ),
                      ),
                      child: Text(
                        '$p',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: selected ? Colors.white : const Color(0xFF455A64),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Profondeur + Temps
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Profondeur (m)'),
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
                    _Label('Temps fond (min)'),
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

          // Consommation
          _Label('Consommation surface (L/min)'),
          const SizedBox(height: 4),
          Text(
            'Débutant ≈ 25 L/min · Confirmé ≈ 20 · Expert ≈ 15',
            style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
          ),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_conso.round()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006064),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Sélecteur de gaz ───

  Widget _buildGasSelector() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '🫁', title: 'Gaz de plongée'),
          const SizedBox(height: 12),
          ...gasMixtures.map((gas) {
            final selected = _selectedGas.name == gas.name;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedGas = gas);
                _compute();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? gas.color.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? gas.color : const Color(0xFFCFD8DC),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(gas.icon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gas.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: selected ? gas.color : const Color(0xFF37474F),
                            ),
                          ),
                          Text(
                            'O₂: ${(gas.fo2 * 100).round()}%  ·  N₂: ${(gas.fn2 * 100).round()}%  ·  MOD: ${gas.modMeters.isInfinite ? "∞" : "${gas.modMeters.round()} m"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF78909C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
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

  // ─── Bouton calculer ───

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

  // ─── Bannière avertissement MOD ───

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('⛔', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profondeur hors limite MOD !',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'La MOD du ${_selectedGas.label} est ${_result!.mod.round()} m. '
                  'Risque d\'hyperoxie (ppO₂ > 1,4 bar).',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Carte consommation gaz ───

  Widget _buildGasConsumptionCard() {
    final r = _result!;
    final totalCapacity = _bottleVolume * _chargePressure;
    final usedPercent = (r.totalVolumeConsumed / totalCapacity).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '🔋', title: 'Consommation de gaz'),
          const SizedBox(height: 16),

          // Jauges
          _GaugeRow(
            label: 'Pression absolue fond',
            value: '${r.pressureAtDepth.toStringAsFixed(1)} bar',
            color: const Color(0xFF0288D1),
          ),
          _GaugeRow(
            label: 'Débit au fond',
            value: '${r.volumeAtDepth.toStringAsFixed(1)} L/min',
            color: const Color(0xFF00838F),
          ),
          _GaugeRow(
            label: 'Volume consommé (total)',
            value: '${r.totalVolumeConsumed.toStringAsFixed(0)} L',
            color: r.hasEnoughGas
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),
          _GaugeRow(
            label: 'Pression consommée',
            value: '${r.totalPressureConsumed.toStringAsFixed(0)} bar',
            color: r.hasEnoughGas
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),

          const SizedBox(height: 16),

          // Barre de progression
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Capacité totale utilisée',
                      style: TextStyle(fontSize: 13, color: Color(0xFF546E7A))),
                  Text(
                    '${(usedPercent * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: usedPercent > 0.8
                          ? const Color(0xFFC62828)
                          : const Color(0xFF006064),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usedPercent,
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation(
                    usedPercent > 0.85
                        ? const Color(0xFFC62828)
                        : usedPercent > 0.65
                            ? const Color(0xFFF57F17)
                            : const Color(0xFF006064),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Réserve & autonomie
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: '⛽',
                  label: 'Réserve',
                  value: '${r.reservePressure.round()} bar',
                  subtitle: '${(_bottleVolume * r.reservePressure).round()} L',
                  color: const Color(0xFFFF6F00),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: '⏱️',
                  label: 'Autonomie fond',
                  value: '${r.autonomyMinutes.toStringAsFixed(0)} min',
                  subtitle: 'hors réserve',
                  color: const Color(0xFF1565C0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Verdict
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
                    : const Color(0xFFEF9A9A),
              ),
            ),
            child: Row(
              children: [
                Text(
                  r.hasEnoughGas ? '✅' : '⚠️',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.hasEnoughGas
                        ? 'Gaz suffisant pour ce profil\n(réserve de ${r.reservePressure.round()} bar conservée)'
                        : 'Gaz insuffisant ! Réduisez la profondeur ou le temps.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: r.hasEnoughGas
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Carte DTR / MN90 ───

  Widget _buildDTRCard() {
    final r = _result!;
    final mn90 = r.mn90;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '📊', title: 'Désaturation · Table MN90'),
          const SizedBox(height: 16),

          if (r.outOfTable) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFCC02)),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hors table MN90 ! Ce profil dépasse les limites de la table. Plongée avec ordinateur obligatoire.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF57F17),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (mn90 == null) ...[
            const Text(
              'Profondeur hors plage MN90 (> 40 m). Utilisez un ordinateur de plongée.',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
            ),
          ] else ...[
            // DTR principal
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF006064), Color(0xFF00838F)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _DTRStat(
                    icon: '⏱️',
                    value: '${mn90['dtr']} min',
                    label: 'DTR total',
                  ),
                  Container(width: 1, height: 50, color: Colors.white24),
                  _DTRStat(
                    icon: '🏷️',
                    value: mn90['g'] as String,
                    label: 'Groupe désat.',
                  ),
                  Container(width: 1, height: 50, color: Colors.white24),
                  _DTRStat(
                    icon: '📍',
                    value: '${mn90['t']} min',
                    label: 'Durée fond',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Paliers
            if ((mn90['stops'] as List).isEmpty) ...[
              _NoStopRow(),
            ] else ...[
              const Text(
                'Paliers de décompression',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF37474F),
                ),
              ),
              const SizedBox(height: 10),
              ...(mn90['stops'] as List).map((stop) {
                return _PalierRow(
                  depth: stop['d'] as int,
                  duration: stop['dur'] as int,
                );
              }),
            ],

            const SizedBox(height: 12),

            // Remontée
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward,
                      color: Color(0xFF006064), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Vitesse de remontée : 9 m/min maximum',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00838F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Carte sécurité ───

  Widget _buildSafetyCard() {
    final r = _result!;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '🛡️', title: 'Sécurité & Narcose'),
          const SizedBox(height: 14),
          _GaugeRow(
            label: 'END (profondeur narcotique équiv. air)',
            value: '${r.end.toStringAsFixed(1)} m',
            color: r.end > 30
                ? const Color(0xFFC62828)
                : const Color(0xFF2E7D32),
          ),
          _GaugeRow(
            label: 'ppO₂ au fond',
            value: '${(r.pressureAtDepth * _selectedGas.fo2).toStringAsFixed(2)} bar',
            color: (r.pressureAtDepth * _selectedGas.fo2) > 1.4
                ? const Color(0xFFC62828)
                : const Color(0xFF2E7D32),
          ),
          _GaugeRow(
            label: 'MOD (${_selectedGas.label})',
            value: r.mod.isInfinite ? '∞' : '${r.mod.round()} m',
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: 12),
          const _SafetyNote(
            icon: '📌',
            text:
                'Palier de sécurité conseillé : 3 minutes à 3 m pour toute plongée (non inclus dans le DTR MN90).',
          ),
          const SizedBox(height: 6),
          const _SafetyNote(
            icon: '📌',
            text: 'Respectez le principe du tiers : 1/3 aller · 1/3 retour · 1/3 réserve.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets réutilisables
// ─────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006064),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF455A64),
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String suffix;
  final ValueChanged<String> onChanged;

  const _NumberInput({
    required this.controller,
    required this.hint,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: Color(0xFF006064),
          fontWeight: FontWeight.bold,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class _GaugeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _GaugeRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
}

class _InfoTile extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
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
}

class _DTRStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _DTRStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
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
}

class _PalierRow extends StatelessWidget {
  final int depth;
  final int duration;
  const _PalierRow({required this.depth, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _NoStopRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: const Row(
        children: [
          Text('✅', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text('Plongée sans palier obligatoire',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
        ],
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  final String icon;
  final String text;
  const _SafetyNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A))),
        ),
      ],
    );
  }
}
