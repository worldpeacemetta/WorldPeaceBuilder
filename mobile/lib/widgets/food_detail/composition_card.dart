import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/food.dart';
import '../../theme.dart';
import 'section_card.dart';

class CompositionCard extends StatefulWidget {
  const CompositionCard({super.key, required this.food});
  final Food food;

  @override
  State<CompositionCard> createState() => _CompositionCardState();
}

class _CompositionCardState extends State<CompositionCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final food = widget.food;
    final proteinKcal = food.protein * 4;
    final carbsKcal = food.carbs * 4;
    final fatKcal = food.fat * 9;
    final total = proteinKcal + carbsKcal + fatKcal;

    if (total <= 0) return const SizedBox.shrink();

    final pctC = carbsKcal / total * 100;
    final pctF = fatKcal / total * 100;
    final pctP = proteinKcal / total * 100;

    // Sections: 0 = carbs, 1 = fat, 2 = protein
    final sections = [
      PieChartSectionData(
        value: carbsKcal,
        color: AppColors.carbs,
        radius: _touched == 0 ? 58.0 : 50.0,
        showTitle: _touched == 0,
        title: '${pctC.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: fatKcal,
        color: AppColors.fat,
        radius: _touched == 1 ? 58.0 : 50.0,
        showTitle: _touched == 1,
        title: '${pctF.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      PieChartSectionData(
        value: proteinKcal,
        color: AppColors.protein,
        radius: _touched == 2 ? 58.0 : 50.0,
        showTitle: _touched == 2,
        title: '${pctP.round()}%',
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    ];

    return SectionCard(
      title: 'Composition',
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: sections,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (event.isInterestedForInteractions &&
                              response?.touchedSection != null) {
                            _touched =
                                response!.touchedSection!.touchedSectionIndex;
                          } else {
                            _touched = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${food.kcal.round()}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.kcalColor,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(fontSize: 10, color: cs.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(
                    color: AppColors.carbs,
                    label: 'Carbs',
                    grams: food.carbs,
                    pct: pctC),
                const SizedBox(height: 14),
                _LegendItem(
                    color: AppColors.fat,
                    label: 'Fat',
                    grams: food.fat,
                    pct: pctF),
                const SizedBox(height: 14),
                _LegendItem(
                    color: AppColors.protein,
                    label: 'Protein',
                    grams: food.protein,
                    pct: pctP),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.grams,
    required this.pct,
  });
  final Color color;
  final String label;
  final double grams;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: cs.textMuted)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${grams.round()} g',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${pct.round()}%',
                style: TextStyle(fontSize: 10, color: cs.textMuted)),
          ],
        ),
      ],
    );
  }
}
