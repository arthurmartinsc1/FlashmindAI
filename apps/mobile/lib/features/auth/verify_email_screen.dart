import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _loading = false;
  bool _resending = false;
  bool _loggingOut = false;
  String? _error;
  String? _successMsg;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pinFocusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pinFocusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _goBack() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref.read(authStateProvider.notifier).logout();
      // GoRouterRefreshNotifier detecta a mudança de estado e redireciona para /login.
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _clearPin() {
    _pinController.clear();
    setState(() {});
    if (!_loading) _pinFocusNode.requestFocus();
  }

  Future<void> _verify(String pin) async {
    if (_loading || pin.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).verifyEmail(pin);
      // Router handles navigation automatically via authStateProvider changes.
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data['detail'] as String?)
          : null;
      if (mounted) setState(() => _error = detail ?? 'Código inválido.');
      _clearPin();
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro inesperado. Tente novamente.');
      _clearPin();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldown = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _cooldown = math.max(0, _cooldown - 1);
        if (_cooldown == 0) _timer?.cancel();
      });
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _successMsg = null;
    });
    try {
      final data = await ref.read(authStateProvider.notifier).resendEmail();
      _startCooldown((data['cooldown_seconds'] as int?) ?? 60);
      setState(() => _successMsg = 'Novo código enviado. Confira seu email.');
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _successMsg = null);
      });
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data['detail'] as String?)
          : null;
      if (mounted) {
        setState(() => _error = detail ?? 'Não foi possível reenviar.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro inesperado.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).userEmail ?? 'seu email';
    final theme = Theme.of(context);
    final pin = _pinController.text;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _loggingOut
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: (_loading || _resending) ? null : _goBack,
              ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        size: 30,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Confirme seu email',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enviamos um código de 6 dígitos para\n$email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, height: 1.5),
                  ),
                  const SizedBox(height: 36),
                  _PinInput(
                    controller: _pinController,
                    focusNode: _pinFocusNode,
                    disabled: _loading,
                    onComplete: _verify,
                    onChanged: () => setState(() {}),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                  if (_successMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline,
                              color: Colors.greenAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _successMsg!,
                            style: const TextStyle(
                                color: Colors.greenAccent, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: (_loading || pin.length < 6)
                        ? null
                        : () => _verify(pin),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: (_cooldown > 0 || _resending) ? null : _resend,
                      child: Text(
                        _cooldown > 0
                            ? 'Reenviar em ${_cooldown}s'
                            : _resending
                                ? 'Reenviando...'
                                : 'Não recebeu o código? Reenviar',
                        style: TextStyle(
                          color: (_cooldown > 0 || _resending)
                              ? Colors.white38
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool disabled;
  final Function(String) onComplete;
  final VoidCallback onChanged;

  const _PinInput({
    required this.controller,
    required this.focusNode,
    required this.disabled,
    required this.onComplete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = controller.text;
    final focused = focusNode.hasFocus;

    return GestureDetector(
      onTap: disabled ? null : () => focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Visual boxes
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  final char = i < text.length ? text[i] : '';
                  final isActive = focused && i == text.length && !disabled;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 44,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : (char.isNotEmpty
                                ? Colors.white38
                                : Colors.white24),
                        width: isActive ? 2 : 1,
                      ),
                      color: const Color(0xFF12122A),
                    ),
                    alignment: Alignment.center,
                    child: char.isNotEmpty
                        ? Text(
                            char,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  );
                }),
              ),
            ),
            // Transparent TextField that captures keyboard input
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(fontSize: 1),
                  decoration: const InputDecoration(
                      border: InputBorder.none, counterText: ''),
                  onChanged: (v) {
                    onChanged();
                    if (v.length == 6) onComplete(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
