import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync_pull_reminder.dart';
import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../services/sync_service.dart';
import '../auth/auth_controller.dart';

final _dashboardProvider = StreamProvider<DashboardDto>((ref) {
  return ref.read(dashboardRepoProvider).watchLocalFirst();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashboardProvider);
    final auth = ref.watch(authStateProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final firstName = (auth.userName ?? 'você').split(' ').first;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bom dia'
        : now.hour < 18
            ? 'Boa tarde'
            : 'Boa noite';

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(syncServiceProvider).syncAll();
        ref.invalidate(_dashboardProvider);
        await ref.read(_dashboardProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFF0B0B12),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting, $firstName!',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Continue construindo consistência',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.account_circle_outlined, color: primary),
                onSelected: (v) {
                  if (v == 'logout') {
                    ref.read(authStateProvider.notifier).logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'logout', child: Text('Sair')),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SyncPullReminder(),
                const SizedBox(height: 12),
                dashAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => _ErrorCard(
                    onRetry: () => ref.invalidate(_dashboardProvider),
                  ),
                  data: (data) => _DashboardBody(data: data),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body principal ──────────────────────────────────────────

class _DashboardBody extends ConsumerWidget {
  final DashboardDto data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewBanner(data: data),
        const SizedBox(height: 16),
        _StatsGrid(data: data),
        const SizedBox(height: 16),
        _ActivityCard(points: data.activityLast30Days),
        const SizedBox(height: 16),
        _DistributionCard(dist: data.cardDistribution),
      ],
    );
  }
}

// ─── Banner de revisão ───────────────────────────────────────

class _ReviewBanner extends ConsumerWidget {
  final DashboardDto data;
  const _ReviewBanner({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = data.dueToday;
    final reviewed = data.reviewedToday;

    final String title;
    final String subtitle;
    final String btnLabel;
    final Color accent;

    if (due > 0) {
      title = '$due ${due == 1 ? 'card' : 'cards'} para revisar';
      subtitle = 'Mantenha sua sequência em dia';
      btnLabel = 'Revisar agora';
      accent = Theme.of(context).colorScheme.primary;
    } else if (reviewed > 0) {
      title = 'Tudo em dia! 🎉';
      subtitle =
          'Você revisou $reviewed ${reviewed == 1 ? 'card' : 'cards'} hoje';
      btnLabel = 'Ver decks';
      accent = Colors.greenAccent;
    } else {
      title = 'Nenhum card vence hoje';
      subtitle = 'O algoritmo está gerenciando seu ritmo';
      btnLabel = 'Ver decks';
      accent = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(70)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(
            onPressed: () {
              context.go(due > 0 ? '/review' : '/decks');
            },
            style: FilledButton.styleFrom(
              backgroundColor: accent.withAlpha(40),
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(btnLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Grid de stats ───────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardDto data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final retention = data.retentionRate;
    final retStr = retention > 0 ? '${retention.toStringAsFixed(0)}%' : '—';

    final items = [
      _StatItem(
        label: 'Para revisar hoje',
        value: '${data.dueToday}',
        icon: Icons.today_outlined,
        color: primary,
      ),
      _StatItem(
        label: 'Streak atual',
        value: '${data.currentStreak} dias',
        icon: Icons.local_fire_department_outlined,
        color: primary,
      ),
      _StatItem(
        label: 'Taxa de retenção',
        value: retStr,
        icon: Icons.trending_up_rounded,
        color: primary,
      ),
      _StatItem(
        label: 'Revisões no mês',
        value: '${data.reviewedMonth}',
        icon: Icons.school_outlined,
        color: primary,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: items,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 20, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Gráfico de atividade ────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final List<ActivityPoint> points;
  const _ActivityCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Atividade — últimos 30 dias',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
          const SizedBox(height: 16),
          _Bars(points: points, color: primary),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  final List<ActivityPoint> points;
  final Color color;
  const _Bars({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 72,
        child: Center(
            child: Text('Sem dados ainda',
                style: TextStyle(color: Colors.white30))),
      );
    }
    final maxVal = points.map((p) => p.count).fold(0, math.max);

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final ratio = maxVal == 0
              ? 0.0
              : (p.count / maxVal).clamp(p.count > 0 ? 0.04 : 0.0, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: FractionallySizedBox(
                heightFactor: ratio == 0.0 ? 0.04 : ratio,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: ratio == 0.04
                        ? color.withAlpha(30)
                        : color.withAlpha(180),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Distribuição de cards ───────────────────────────────────

class _DistributionCard extends StatelessWidget {
  final CardDistribution dist;
  const _DistributionCard({required this.dist});

  @override
  Widget build(BuildContext context) {
    final total = dist.total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Distribuição dos cards',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70)),
          const SizedBox(height: 14),
          if (total == 0)
            const Text('Nenhum card ainda',
                style: TextStyle(color: Colors.white30))
          else ...[
            _DistBar(
                label: 'Novos',
                count: dist.newCards,
                total: total,
                color: Colors.blue),
            const SizedBox(height: 8),
            _DistBar(
                label: 'Aprendendo',
                count: dist.learning,
                total: total,
                color: Colors.amber),
            const SizedBox(height: 8),
            _DistBar(
                label: 'Maduros',
                count: dist.mature,
                total: total,
                color: Colors.greenAccent),
          ],
        ],
      ),
    );
  }
}

class _DistBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  const _DistBar(
      {required this.label,
      required this.count,
      required this.total,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            Text('$count',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─── Error card ──────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('Sem conexão',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Verifique sua internet e tente novamente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          FilledButton.tonal(
              onPressed: onRetry, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
