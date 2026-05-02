import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity_service.dart';
import '../../core/sync_pull_reminder.dart';
import '../../data/db/database.dart';
import '../../data/repositories.dart';
import '../../domain/models.dart';
import '../../services/sync_service.dart';

final _deckProvider = StreamProvider.family<DeckRow?, String>((ref, deckId) {
  final repo = ref.watch(deckRepoProvider);
  repo.pullDeckInBackground(deckId);
  return repo.watchDeck(deckId);
});

final _cardsProvider =
    StreamProvider.family<List<CardRow>, String>((ref, deckId) {
  final repo = ref.watch(cardRepoProvider);
  repo.pullCardsForDeckInBackground(deckId);
  return repo.watchCardsForDeck(deckId);
});

final _lessonsProvider =
    StreamProvider.family<List<LessonSummaryDto>, String>((ref, deckId) {
  return ref.watch(lessonRepoProvider).watchLessons(deckId);
});

final _lessonDetailProvider =
    StreamProvider.family<LessonDetailDto?, String>((ref, lessonId) {
  return ref.watch(lessonRepoProvider).watchLesson(lessonId);
});

final _deckTabProvider = StateProvider.family<int, String>((ref, deckId) => 0);
final _openLessonProvider =
    StateProvider.family<String?, String>((ref, deckId) => null);

const _editableDeckColors = [
  '#6366F1',
  '#8B5CF6',
  '#EC4899',
  '#F43F5E',
  '#F59E0B',
  '#10B981',
  '#06B6D4',
  '#3B82F6',
];

class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deckAsync = ref.watch(_deckProvider(deckId));
    final cardsAsync = ref.watch(_cardsProvider(deckId));
    final lessonsAsync = ref.watch(_lessonsProvider(deckId));
    final selectedTab = ref.watch(_deckTabProvider(deckId));
    final isOnline = ref.watch(isOnlineProvider).value ?? true;

    Future<void> refresh() async {
      await ref.read(syncServiceProvider).syncAll();
      await _refetchDeckData(ref, deckId);
    }

    return Scaffold(
      body: deckAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: readableDeckError(e)),
        data: (deck) {
          if (deck == null) {
            return const _SyncingState();
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: const Color(0xFF0B0B12),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  title: Text(deck.title, maxLines: 1),
                  actions: [
                    IconButton(
                      tooltip: 'Editar deck',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditDeckSheet(context, deck),
                    ),
                    IconButton(
                      tooltip: 'Arquivar deck',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmArchiveDeck(context, ref, deck),
                    ),
                    IconButton(
                      tooltip: 'Revisar',
                      icon: const Icon(Icons.school_outlined),
                      onPressed: () => context.push('/study/${deck.id}'),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _DeckHeader(deck: deck),
                      const SizedBox(height: 16),
                      const SyncPullReminder(),
                      const SizedBox(height: 16),
                      _ActionPanel(deck: deck, isOnline: isOnline),
                      const SizedBox(height: 20),
                      _DeckTabs(
                        selected: selectedTab,
                        onSelected: (tab) => ref
                            .read(_deckTabProvider(deckId).notifier)
                            .state = tab,
                      ),
                      const SizedBox(height: 10),
                      if (selectedTab == 0)
                        _CardsTab(
                          deckId: deck.id,
                          cardsAsync: cardsAsync,
                          lessonsAsync: lessonsAsync,
                        )
                      else
                        _MicroLessonsTab(deckId: deck.id),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> _refetchDeckData(WidgetRef ref, String deckId) async {
  await Future.wait([
    _ignoreSyncError(ref.read(deckRepoProvider).pullDeck(deckId)),
    _ignoreSyncError(ref.read(cardRepoProvider).pullCardsForDeck(deckId)),
    _ignoreSyncError(ref.read(lessonRepoProvider).list(deckId)),
  ]);
}

Future<void> _ignoreSyncError<T>(Future<T> future) async {
  try {
    await future;
  } catch (_) {}
}

void _showEditDeckSheet(BuildContext context, DeckRow deck) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF13131F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EditDeckSheet(deck: deck),
  );
}

Future<void> _confirmArchiveDeck(
  BuildContext context,
  WidgetRef ref,
  DeckRow deck,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Arquivar deck?'),
      content: Text(
        'O deck "${deck.title}" será removido da sua lista de decks ativos.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Arquivar'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(deckRepoProvider).archiveDeck(deck.id);
    if (!context.mounted) return;
    context.go('/decks');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deck arquivado.')),
    );
  } on DioException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_dioErrorMessage(
          e,
          fallback: 'Não foi possível arquivar o deck.',
        )),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro inesperado ao arquivar o deck.')),
    );
  }
}

class _EditDeckSheet extends ConsumerStatefulWidget {
  const _EditDeckSheet({required this.deck});

  final DeckRow deck;

  @override
  ConsumerState<_EditDeckSheet> createState() => _EditDeckSheetState();
}

class _EditDeckSheetState extends ConsumerState<_EditDeckSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _color;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.deck.title);
    _description = TextEditingController(text: widget.deck.description);
    _color = widget.deck.color;
    if (!_editableDeckColors.contains(_color)) {
      _color = _editableDeckColors.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nome do deck obrigatório.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(deckRepoProvider).updateDeck(
            deckId: widget.deck.id,
            title: title,
            description: _description.text.trim(),
            color: _color,
          );
      await _refetchDeckData(ref, widget.deck.id);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = _dioErrorMessage(
              e,
              fallback: 'Não foi possível editar o deck.',
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao editar o deck.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: 'Editar deck',
              loading: _loading,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_loading,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                context,
                label: 'Nome *',
                hint: 'Nome do deck',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_loading,
              maxLines: 2,
              decoration: _fieldDecoration(
                context,
                label: 'Descrição',
                hint: 'Descrição opcional',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cor',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _editableDeckColors.map((hex) {
                final color = _deckColor(hex);
                final selected = hex == _color;
                return GestureDetector(
                  onTap: _loading ? null : () => setState(() => _color = hex),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            _Feedback(error: _error),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading ? const _TinySpinner() : const Icon(Icons.check),
              label: Text(_loading ? 'Salvando...' : 'Salvar alterações'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckHeader extends StatelessWidget {
  const _DeckHeader({required this.deck});

  final DeckRow deck;

  @override
  Widget build(BuildContext context) {
    final color = _deckColor(deck.color);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        border: Border.all(color: const Color(0xFF2A2A3D)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (deck.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    deck.description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '${deck.cardCount} cards · ${deck.dueCount} para revisar',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.deck, required this.isOnline});

  final DeckRow deck;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.auto_awesome_rounded,
            title: 'Gerar com IA',
            subtitle: 'Tópico ou texto',
            color: const Color(0xFFF59E0B),
            onTap: () => _showGenerateCardsSheet(context, deck, isOnline),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            title: 'Adicionar manualmente',
            subtitle: 'Frente e verso',
            color: Theme.of(context).colorScheme.primary,
            onTap: () => _showManualCardSheet(context, deck),
          ),
        ),
      ],
    );
  }
}

class _DeckTabs extends StatelessWidget {
  const _DeckTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Cards',
            selected: selected == 0,
            onTap: () => onSelected(0),
          ),
          _TabButton(
            label: 'Micro-lições',
            selected: selected == 1,
            onTap: () => onSelected(1),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsTab extends StatelessWidget {
  const _CardsTab({
    required this.deckId,
    required this.cardsAsync,
    required this.lessonsAsync,
  });

  final String deckId;
  final AsyncValue<List<CardRow>> cardsAsync;
  final AsyncValue<List<LessonSummaryDto>> lessonsAsync;

  @override
  Widget build(BuildContext context) {
    final hasIncompleteLessons = lessonsAsync.maybeWhen(
      data: (lessons) => lessons.isNotEmpty && lessons.any((l) => !l.completed),
      orElse: () => false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasIncompleteLessons) ...[
          const _LockedCardsNotice(),
          const SizedBox(height: 10),
        ],
        cardsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _InlineMessage(readableDeckError(e)),
          data: (cards) {
            if (cards.isEmpty) {
              return const _InlineMessage(
                'Nenhum card ainda. Gere com IA ou adicione manualmente.',
              );
            }
            return Column(
              children: cards
                  .map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CardTile(deckId: deckId, card: card),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LockedCardsNotice extends StatelessWidget {
  const _LockedCardsNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: Color(0xFFFBBF24), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Cards gerados com IA ficam bloqueados para revisão até você concluir uma micro-lição.',
              style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Material(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A3D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withAlpha(34),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTile extends ConsumerStatefulWidget {
  const _CardTile({required this.deckId, required this.card});

  final String deckId;
  final CardRow card;

  @override
  ConsumerState<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends ConsumerState<_CardTile> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  bool _editing = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.card.front);
    _back = TextEditingController(text: widget.card.back);
  }

  @override
  void didUpdateWidget(covariant _CardTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id || !_editing) {
      _front.text = widget.card.front;
      _back.text = widget.card.back;
    }
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final front = _front.text.trim();
    final back = _back.text.trim();
    if (front.isEmpty || back.isEmpty) {
      setState(() => _error = 'Preencha frente e verso do card.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(cardRepoProvider).updateCard(
            deckId: widget.deckId,
            cardId: widget.card.id,
            front: front,
            back: back,
          );
      await _refetchDeckData(ref, widget.deckId);
      if (!mounted) return;
      setState(() => _editing = false);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = _dioErrorMessage(
              e,
              fallback: 'Não foi possível editar o card.',
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao editar o card.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir card?'),
        content: const Text('Essa ação remove o card deste deck.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(cardRepoProvider).deleteCard(
            deckId: widget.deckId,
            cardId: widget.card.id,
          );
      await _refetchDeckData(ref, widget.deckId);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = _dioErrorMessage(
              e,
              fallback: 'Não foi possível excluir o card.',
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao excluir o card.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancel() {
    _front.text = widget.card.front;
    _back.text = widget.card.back;
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _front,
              enabled: !_loading,
              maxLines: 3,
              decoration: _fieldDecoration(
                context,
                label: 'Frente *',
                hint: 'Pergunta ou conceito',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _back,
              enabled: !_loading,
              maxLines: 3,
              decoration: _fieldDecoration(
                context,
                label: 'Verso *',
                hint: 'Resposta ou definição',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _loading ? null : _cancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const _TinySpinner()
                        : const Icon(Icons.check),
                    label: Text(_loading ? 'Salvando...' : 'Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.card.front,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Editar card',
                visualDensity: VisualDensity.compact,
                onPressed:
                    _loading ? null : () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Excluir card',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.card.back,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _MicroLessonsTab extends ConsumerWidget {
  const _MicroLessonsTab({required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openLessonId = ref.watch(_openLessonProvider(deckId));
    if (openLessonId != null) {
      return _LessonDetailView(deckId: deckId, lessonId: openLessonId);
    }

    final lessonsAsync = ref.watch(_lessonsProvider(deckId));
    return lessonsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineMessage(readableDeckError(e)),
      data: (lessons) {
        if (lessons.isEmpty) {
          return const _InlineMessage(
            'Ainda não há micro-lições. Gere cards com IA para criar uma lição curta automaticamente.',
          );
        }

        const maxLessons = 3;
        final done = lessons.where((l) => l.completed).length;
        final allDone = done == lessons.length;
        final atLimit = lessons.length >= maxLessons;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allDone
                            ? 'Todas as lições concluídas'
                            : 'Sua trilha de lições',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$done de ${lessons.length} concluída${done == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: done / lessons.length,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF2A2A3D),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (atLimit && !allDone) ...[
              const _LessonLimitNotice(maxLessons: maxLessons),
              const SizedBox(height: 10),
            ] else if (done == 0) ...[
              const _MicroLessonIntro(),
              const SizedBox(height: 10),
            ],
            ...lessons.asMap().entries.map((entry) {
              final index = entry.key;
              final lesson = entry.value;
              final isNext = !lesson.completed &&
                  lessons.take(index).every((item) => item.completed);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LessonTile(
                  lesson: lesson,
                  index: index,
                  isNext: isNext,
                  onTap: () => ref
                      .read(_openLessonProvider(deckId).notifier)
                      .state = lesson.id,
                ),
              );
            }),
            if (allDone) ...[
              const SizedBox(height: 4),
              _ReviewReadyNotice(deckId: deckId),
            ],
          ],
        );
      },
    );
  }
}

class _LessonLimitNotice extends StatelessWidget {
  const _LessonLimitNotice({required this.maxLessons});

  final int maxLessons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
      ),
      child: Text(
        'Limite de $maxLessons lições atingido. Conclua as lições abaixo antes de gerar mais conteúdo com IA.',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}

class _MicroLessonIntro extends StatelessWidget {
  const _MicroLessonIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(70),
        ),
      ),
      child: const Text(
        'Micro-lições ensinam o tema em poucos minutos antes da revisão. Conclua uma lição para liberar os cards gerados com IA.',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.index,
    required this.isNext,
    required this.onTap,
  });

  final LessonSummaryDto lesson;
  final int index;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF13131F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A3D)),
          ),
          child: Row(
            children: [
              if (lesson.completed)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.greenAccent)
              else
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isNext
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF2A2A3D),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isNext ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.estimatedMinutes} min'
                      '${lesson.completed ? ' · Concluída' : ''}'
                      '${isNext ? ' · Próxima' : ''}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewReadyNotice extends StatelessWidget {
  const _ReviewReadyNotice({required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withAlpha(70)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Ótimo. Agora revise os flashcards liberados.',
              style: TextStyle(color: Colors.greenAccent, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/study/$deckId'),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}

class _LessonDetailView extends ConsumerWidget {
  const _LessonDetailView({required this.deckId, required this.lessonId});

  final String deckId;
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_lessonDetailProvider(lessonId));
    return detailAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineMessage(readableDeckError(e)),
      data: (lesson) {
        if (lesson == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _LessonPlayer(deckId: deckId, lesson: lesson);
      },
    );
  }
}

class _LessonPlayer extends ConsumerStatefulWidget {
  const _LessonPlayer({required this.deckId, required this.lesson});

  final String deckId;
  final LessonDetailDto lesson;

  @override
  ConsumerState<_LessonPlayer> createState() => _LessonPlayerState();
}

class _LessonPlayerState extends ConsumerState<_LessonPlayer> {
  final Set<String> _answeredQuizIds = {};
  bool _completed = false;
  bool _completing = false;
  int _unlocked = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completed = widget.lesson.completed;
  }

  Future<void> _complete() async {
    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(lessonRepoProvider).complete(widget.lesson.id);
      ref.invalidate(_lessonDetailProvider(widget.lesson.id));
      await _refetchDeckData(ref, widget.deckId);
      if (!mounted) return;
      setState(() {
        _completed = true;
        _unlocked = result.unlockedCardsCount;
      });
    } on DioException catch (e) {
      setState(() => _error = _dioErrorMessage(
            e,
            fallback: 'Não foi possível concluir a lição.',
          ));
    } catch (_) {
      setState(() => _error = 'Erro inesperado ao concluir a lição.');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      return _LessonCompleted(
        deckId: widget.deckId,
        unlockedCards: _unlocked,
        onBack: () =>
            ref.read(_openLessonProvider(widget.deckId).notifier).state = null,
      );
    }

    final quizIds = widget.lesson.blocks
        .where((block) => block.type == 'quiz')
        .map((block) => block.id)
        .toList();
    final canComplete =
        quizIds.every(_answeredQuizIds.contains) || quizIds.isEmpty;
    final remaining = quizIds.length - _answeredQuizIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => ref
                  .read(_openLessonProvider(widget.deckId).notifier)
                  .state = null,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Lições'),
            ),
            const Spacer(),
            if (quizIds.isNotEmpty)
              Text(
                '${_answeredQuizIds.length}/${quizIds.length} quizzes',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.lesson.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.lesson.estimatedMinutes} min · ${widget.lesson.blocks.length} blocos',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ...widget.lesson.blocks.map((block) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LessonBlockView(
                block: block,
                onQuizAnswered: () {
                  setState(() => _answeredQuizIds.add(block.id));
                },
              ),
            )),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF13131F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A3D)),
          ),
          child: Column(
            children: [
              if (!canComplete)
                Text(
                  'Responda ${remaining == 1 ? 'o quiz' : 'os $remaining quizzes'} acima para concluir.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                )
              else ...[
                const Icon(Icons.check_circle_outline,
                    color: Colors.greenAccent),
                const SizedBox(height: 8),
                const Text(
                  'Lição concluída. Marque como feita para liberar a revisão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _completing ? null : _complete,
                  icon: _completing
                      ? const _TinySpinner()
                      : const Icon(Icons.celebration_outlined),
                  label: Text(_completing ? 'Concluindo...' : 'Concluir lição'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonCompleted extends StatelessWidget {
  const _LessonCompleted({
    required this.deckId,
    required this.unlockedCards,
    required this.onBack,
  });

  final String deckId;
  final int unlockedCards;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration_outlined,
              color: Colors.greenAccent, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Lição concluída',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            unlockedCards > 0
                ? '$unlockedCards cards liberados para revisão.'
                : 'Seu esforço está virando domínio.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onBack,
                  child: const Text('Outras lições'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/study/$deckId'),
                  child: const Text('Revisar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonBlockView extends StatefulWidget {
  const _LessonBlockView({
    required this.block,
    required this.onQuizAnswered,
  });

  final ContentBlockDto block;
  final VoidCallback onQuizAnswered;

  @override
  State<_LessonBlockView> createState() => _LessonBlockViewState();
}

class _LessonBlockViewState extends State<_LessonBlockView> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    if (block.type == 'quiz') {
      return _QuizBlock(
        content: block.content,
        selected: _selected,
        onSelected: (idx) {
          if (_selected != null) return;
          setState(() => _selected = idx);
          widget.onQuizAnswered();
        },
      );
    }

    if (block.type == 'highlight') {
      return _HighlightBlock(content: block.content);
    }

    return _TextBlock(content: block.content);
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    return Text(
      (content['body'] as String?) ?? '',
      style: const TextStyle(fontSize: 14, height: 1.45, color: Colors.white70),
    );
  }
}

class _HighlightBlock extends StatelessWidget {
  const _HighlightBlock({required this.content});

  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline,
              color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (content['body'] as String?) ?? '',
              style: const TextStyle(color: Color(0xFFFDE68A), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizBlock extends StatelessWidget {
  const _QuizBlock({
    required this.content,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, dynamic> content;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = ((content['options'] as List?) ?? []).cast<Object>();
    final correct = (content['correct'] as int?) ?? 0;
    final answered = selected != null;
    final explanation = (content['explanation'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (content['question'] as String?) ?? '',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (idx) {
            final isCorrect = idx == correct;
            final isSelected = selected == idx;
            Color border = const Color(0xFF2A2A3D);
            Color bg = const Color(0xFF0E0E1A);
            if (answered && isCorrect) {
              border = Colors.greenAccent;
              bg = Colors.greenAccent.withAlpha(18);
            } else if (answered && isSelected && !isCorrect) {
              border = Colors.redAccent;
              bg = Colors.redAccent.withAlpha(18);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: answered ? null : () => onSelected(idx),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    options[idx].toString(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            );
          }),
          if (answered && explanation.isNotEmpty)
            Text(
              explanation,
              style: TextStyle(
                color:
                    selected == correct ? Colors.greenAccent : Colors.redAccent,
                fontSize: 12,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

void _showGenerateCardsSheet(
  BuildContext context,
  DeckRow deck,
  bool isOnline,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF13131F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GenerateCardsSheet(deck: deck, initialOnline: isOnline),
  );
}

class _GenerateCardsSheet extends ConsumerStatefulWidget {
  const _GenerateCardsSheet({
    required this.deck,
    required this.initialOnline,
  });

  final DeckRow deck;
  final bool initialOnline;

  @override
  ConsumerState<_GenerateCardsSheet> createState() =>
      _GenerateCardsSheetState();
}

class _GenerateCardsSheetState extends ConsumerState<_GenerateCardsSheet> {
  final _topic = TextEditingController();
  final _sourceText = TextEditingController();
  int _count = 8;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _topic.dispose();
    _sourceText.dispose();
    super.dispose();
  }

  Future<void> _submit(bool isOnline) async {
    final topic = _topic.text.trim();
    if (!isOnline) {
      setState(
          () => _error = 'Conecte-se à internet para gerar flashcards com IA.');
      return;
    }
    if (topic.length < 3) {
      setState(() => _error = 'Informe um tópico com pelo menos 3 caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final job = await ref.read(deckRepoProvider).generateCards(
            deckId: widget.deck.id,
            topic: topic,
            count: _count,
            sourceText: _sourceText.text,
          );

      if (!mounted) return;

      if (job.isCompleted) {
        await _refreshDeckData();
        final created = (job.result?['created_count'] as int?) ?? 0;
        final skipped = (job.result?['skipped_count'] as int?) ?? 0;
        setState(() {
          _success = created > 0
              ? '$created ${created == 1 ? 'card criado' : 'cards criados'} com IA.'
              : 'Geração concluída, mas nenhum card novo foi criado.';
          if (skipped > 0) {
            _success = '$_success $skipped ignorados por limite do deck.';
          }
        });
      } else if (job.isFailed) {
        setState(() => _error = _friendlyGenerationError(job.error));
      } else {
        await _refreshDeckData();
        setState(() =>
            _success = 'Pedido enviado. A geração continua em segundo plano.');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = _dioErrorMessage(
              e,
              fallback: 'Não foi possível gerar agora.',
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao gerar com IA.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshDeckData() async {
    await _refetchDeckData(ref, widget.deck.id);
  }

  void _openMicroLessons() {
    ref.read(_deckTabProvider(widget.deck.id).notifier).state = 1;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isOnline = ref.watch(isOnlineProvider).value ?? widget.initialOnline;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: 'Gerar com IA',
              loading: _loading,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(28),
                border:
                    Border.all(color: const Color(0xFFF59E0B).withAlpha(90)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFFFBBF24), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Só pode ser feita a geração de cards com IA se online.',
                      style: TextStyle(color: Color(0xFFFDE68A), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _topic,
              enabled: !_loading,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                context,
                label: 'Tópico *',
                hint: 'Ex.: Ciclo de Krebs',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Quantidade',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                const Spacer(),
                IconButton(
                  onPressed: _loading || _count <= 1
                      ? null
                      : () => setState(() => _count--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_count',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: _loading || _count >= 20
                      ? null
                      : () => setState(() => _count++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceText,
              enabled: !_loading,
              maxLines: 4,
              maxLength: 8000,
              decoration: _fieldDecoration(
                context,
                label: 'Texto-fonte (opcional)',
                hint: 'Cole um trecho do seu material de estudo.',
              ),
            ),
            _Feedback(error: _error, success: _success),
            if (_success != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _openMicroLessons,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Ver micro-lição'),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading || !isOnline ? null : () => _submit(isOnline),
              icon: _loading
                  ? const _TinySpinner()
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? 'Gerando...' : 'Gerar flashcards'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showManualCardSheet(
  BuildContext context,
  DeckRow deck,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF13131F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ManualCardSheet(deck: deck),
  );
}

class _ManualCardSheet extends ConsumerStatefulWidget {
  const _ManualCardSheet({
    required this.deck,
  });

  final DeckRow deck;

  @override
  ConsumerState<_ManualCardSheet> createState() => _ManualCardSheetState();
}

class _ManualCardSheetState extends ConsumerState<_ManualCardSheet> {
  final _front = TextEditingController();
  final _back = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_front.text.trim().isEmpty || _back.text.trim().isEmpty) {
      setState(() => _error = 'Preencha frente e verso do card.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(cardRepoProvider).createCard(
            deckId: widget.deck.id,
            front: _front.text.trim(),
            back: _back.text.trim(),
          );
      await _refetchDeckData(ref, widget.deck.id);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = _dioErrorMessage(
              e,
              fallback: 'Não foi possível salvar o card.',
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Erro inesperado ao salvar o card.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: 'Adicionar manualmente',
              loading: _loading,
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _front,
              enabled: !_loading,
              maxLines: 3,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration(
                context,
                label: 'Frente *',
                hint: 'Pergunta ou conceito',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _back,
              enabled: !_loading,
              maxLines: 3,
              decoration: _fieldDecoration(
                context,
                label: 'Verso *',
                hint: 'Resposta ou definição',
              ),
            ),
            _Feedback(error: _error),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading ? const _TinySpinner() : const Icon(Icons.save),
              label: Text(_loading ? 'Salvando...' : 'Salvar card'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.loading,
    required this.onClose,
  });

  final String title;
  final bool loading;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: loading ? null : onClose,
        ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({this.error, this.success});

  final String? error;
  final String? success;

  @override
  Widget build(BuildContext context) {
    if (error == null && success == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        error ?? success!,
        style: TextStyle(
          color: error == null ? Colors.greenAccent : Colors.redAccent,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _TinySpinner extends StatelessWidget {
  const _TinySpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13131F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3D)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }
}

class _SyncingState extends StatelessWidget {
  const _SyncingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Sincronizando deck...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  required String label,
  required String hint,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFF0E0E1A),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: primary, width: 1.5),
    ),
  );
}

Color _deckColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF6366F1);
  }
}

String _friendlyGenerationError(String raw) {
  final lower = raw.toLowerCase();
  if (lower.contains('unauthorized') ||
      lower.contains('401') ||
      lower.contains('groqclienterror')) {
    return 'A IA recusou a requisição. Verifique se a GROQ_API_KEY do worker está válida e reinicie o worker.';
  }
  if (lower.contains('groq_api_key') || lower.contains('groqmissingkey')) {
    return 'A chave da Groq não está configurada no worker.';
  }
  if (raw.trim().isEmpty) {
    return 'A geração falhou. Tente novamente.';
  }
  return raw;
}

String _dioErrorMessage(DioException e, {required String fallback}) {
  if (e.response?.statusCode == 401) {
    return 'Sua sessão expirou. Entre novamente e tente gerar os cards.';
  }

  final data = e.response?.data;
  final detail = data is Map ? _stringifyErrorDetail(data['detail']) : null;
  if (detail == null || detail.trim().isEmpty) return fallback;

  final lower = detail.toLowerCase();
  if (lower.contains('unauthorized')) {
    return 'Sua sessão expirou. Entre novamente e tente gerar os cards.';
  }
  return detail;
}

String readableDeckError(Object error) {
  if (error is DioException) {
    return _dioErrorMessage(
      error,
      fallback: 'Não foi possível carregar os dados do backend.',
    );
  }
  final message = error.toString();
  if (message.trim().isEmpty) {
    return 'Não foi possível carregar os dados do backend.';
  }
  return message;
}

String? _stringifyErrorDetail(Object? detail) {
  if (detail == null) return null;
  if (detail is String) return detail;
  if (detail is List) {
    return detail.map(_stringifyErrorDetail).whereType<String>().join('\n');
  }
  if (detail is Map) {
    final firstValue = detail.values.isEmpty ? null : detail.values.first;
    final message = detail['msg'] ??
        detail['message'] ??
        detail['detail'] ??
        detail['loc'] ??
        firstValue;
    return _stringifyErrorDetail(message) ?? detail.toString();
  }
  return detail.toString();
}
