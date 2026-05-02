import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'flip_card.dart';
import 'study_controller.dart';

class StudyScreen extends ConsumerWidget {
  const StudyScreen({super.key, required this.deckId});
  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyControllerProvider(deckId));
    final ctrl = ref.read(studyControllerProvider(deckId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.loading
            ? 'Carregando...'
            : state.finished
                ? 'Sessão concluída'
                : '${state.index + 1} / ${state.queue.length} cards'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _body(state, ctrl),
        ),
      ),
    );
  }

  Widget _body(StudyState state, StudyController ctrl) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.queue.isEmpty) {
      return const _EmptyState(message: 'Nenhum card pendente neste deck. ');
    }
    if (state.finished) {
      return _ReviewSummary(state: state);
    }

    final card = state.current!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (state.index + 1) / (state.queue.length),
          backgroundColor: Colors.white12,
          minHeight: 4,
        ),
        const SizedBox(height: 8),
        Text(
          '${state.index + 1} de ${state.queue.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: FlipCard(
                showBack: state.flipped,
                onTap: ctrl.flip,
                front: _CardText(text: card.front, label: 'Pergunta'),
                back: _CardText(text: card.back, label: 'Resposta'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!state.flipped)
          FilledButton(
            onPressed: ctrl.flip,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Mostrar resposta'),
          )
        else
          _GradeBar(onGrade: ctrl.grade),
      ],
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.state});

  final StudyState state;

  @override
  Widget build(BuildContext context) {
    final total = state.reviewed == 0 ? 1 : state.reviewed;
    final accuracy = (state.correct / total * 100).round();
    final avgMs = state.reviewed == 0 ? 0 : state.totalTimeMs ~/ state.reviewed;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF141421),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 58,
                    color: Color(0xFF7C6DFF),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Revisão concluída',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${state.reviewed} ${state.reviewed == 1 ? 'card revisado' : 'cards revisados'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Acertos',
                          value: '${state.correct}',
                          color: const Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Erros',
                          value: '${state.wrong}',
                          color: const Color(0xFFF87171),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Precisão',
                          value: '$accuracy%',
                          color: const Color(0xFF7C6DFF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryMetric(
                          label: 'Tempo',
                          value: _formatDuration(state.totalTimeMs),
                          detail: '${_formatDuration(avgMs)} por card',
                          color: const Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go('/review'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('Ver próximas revisões'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => context.pop(),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final seconds = (milliseconds / 1000).round();
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return rest == 0 ? '${minutes}min' : '${minutes}min ${rest}s';
}

class _CardText extends StatelessWidget {
  const _CardText({required this.text, required this.label});
  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, height: 1.35),
        ),
      ],
    );
  }
}

class _GradeBar extends StatelessWidget {
  const _GradeBar({required this.onGrade});
  final void Function(int quality) onGrade;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      (0, 'De novo', Colors.redAccent),
      (3, 'Difícil', Colors.orangeAccent),
      (4, 'Bom', Colors.lightGreen),
      (5, 'Fácil', Colors.greenAccent),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: buttons.map((b) {
        final (q, label, color) = b;
        return SizedBox(
          width: 150,
          child: FilledButton.tonal(
            onPressed: () => onGrade(q),
            style: FilledButton.styleFrom(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(label),
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration_outlined,
              size: 64, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => context.pop(),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}
