import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style_rounded),
            label: 'Decks',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school_rounded),
            label: 'Revisar',
          ),
        ],
      ),
      floatingActionButton: index == 1 ? const _CreateDeckFab() : null,
    );
  }
}

// ─── FAB criar deck ──────────────────────────────────────────

class _CreateDeckFab extends StatelessWidget {
  const _CreateDeckFab();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'create_deck',
      onPressed: () => _showCreateDeckSheet(context),
      child: const Icon(Icons.add),
    );
  }

  void _showCreateDeckSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13131F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateDeckSheet(),
    );
  }
}

const _deckColors = [
  '#6366F1',
  '#8B5CF6',
  '#EC4899',
  '#F43F5E',
  '#F59E0B',
  '#10B981',
  '#06B6D4',
  '#3B82F6',
];

class _CreateDeckSheet extends ConsumerStatefulWidget {
  const _CreateDeckSheet();

  @override
  ConsumerState<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends ConsumerState<_CreateDeckSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _color = _deckColors.first;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nome do deck obrigatório');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(deckRepoProvider).createDeck(
            title: title,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            color: _color,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Não foi possível criar o deck.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Novo deck',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nome *',
              filled: true,
              fillColor: const Color(0xFF0E0E1A),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Descrição (opcional)',
              filled: true,
              fillColor: const Color(0xFF0E0E1A),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Cor',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _deckColors.map((hex) {
              final c =
                  Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              final selected = hex == _color;
              return GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Criar deck'),
          ),
        ],
      ),
    );
  }
}
