import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../widgets/ui.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Range { week, month, year }

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Range _range = _Range.week;
  // Stable reference day: a fresh DateTime.now() on every rebuild would
  // create a new provider argument each time and never leave "loading".
  late final DateTime _refDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(weekReportProvider(_refDay));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          LargeHeader('Reports', trailing: TextButton(
            onPressed: () => _export(),
            child: const Text('Export', style: TextStyle(fontSize: 15)),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Segmented(
              labels: const ['Week', 'Month', 'Year'],
              selected: _range.index,
              onSelect: (i) => setState(() => _range = _Range.values[i]),
            ),
          ),
          const SizedBox(height: 14),
          report.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Group(children: [
              GRow(child: Text('Could not load report',
                  style: TextStyle(color: sub(context)))),
            ]),
            data: (r) => Column(children: [
              _totalCard(r),
              if (r.byProject.isNotEmpty) ...[
                const SectionTitle('By project'),
                Group(padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _slices(r)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _totalCard(ReportSummary r) {
    final total = r.totalSeconds == 0 ? Duration.zero : Duration(seconds: r.totalSeconds);
    final billablePct = r.totalSeconds == 0
        ? 0.0
        : r.billableSeconds / r.totalSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 2)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_rangeLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub(context))),
          const SizedBox(height: 2),
          Text(hm(total),
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5, color: ink(context))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: billablePct,
              minHeight: 10,
              backgroundColor: sep(context),
              valueColor: const AlwaysStoppedAnimation(T.green),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(billablePct * 100).round()}% billable',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sub(context))),
        ]),
      ),
    );
  }

  String get _rangeLabel => switch (_range) {
        _Range.week => 'THIS WEEK',
        _Range.month => 'THIS MONTH',
        _Range.year => 'THIS YEAR',
      };

  Widget _slices(ReportSummary r) {
    final palette = [T.blue, T.green, T.orange, T.indigo, const Color(0xFFBF5AF2), T.red];
    final max = r.byProject.first.seconds;
    return Column(children: [
      for (var i = 0; i < r.byProject.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(
                color: palette[i % palette.length], borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 10),
            Expanded(child: Text(r.byProject[i].name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: ink(context)))),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : r.byProject[i].seconds / max,
                  minHeight: 6,
                  backgroundColor: sep(context),
                  valueColor: AlwaysStoppedAnimation(palette[i % palette.length]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 46,
                child: Text(hm(Duration(seconds: r.byProject[i].seconds)),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink(context)))),
          ]),
        ),
    ]);
  }

  void _export() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('CSV/PDF export — coming in the next iteration.')));
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : T.fieldBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: selected == i ? surface(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected == i
                      ? [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 3)]
                      : null,
                ),
                child: Center(child: Text(labels[i], style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected == i ? ink(context) : sub(context)))),
              ),
            ),
          ),
      ]),
    );
  }
}
