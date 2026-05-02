import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand_mark.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Senha obrigatória';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Precisa ter ao menos 1 letra maiúscula';
    }
    if (!RegExp(r'\d').hasMatch(v)) return 'Precisa ter ao menos 1 número';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .register(_name.text.trim(), _email.text.trim(), _password.text);
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data['detail'] as String?)
          : null;
      setState(() => _error = detail ?? 'Não foi possível criar a conta.');
    } catch (_) {
      setState(() => _error = 'Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF13131F);
    const borderColor = Color(0xFF2A2A3D);
    final primary = Theme.of(context).colorScheme.primary;

    final inputDecoration = InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0E0E1A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIconColor: Colors.white38,
    );

    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: inputDecoration),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: _loading ? null : () => context.go('/login'),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const BrandMark(size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'Crie sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Grátis. Sem cartão de crédito.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 28),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Nome
                            const _Label('Nome'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _name,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              autocorrect: false,
                              enabled: !_loading,
                              decoration: const InputDecoration(
                                hintText: 'Como devemos te chamar?',
                                hintStyle: TextStyle(color: Colors.white24),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nome obrigatório'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Email
                            const _Label('Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              enabled: !_loading,
                              decoration: const InputDecoration(
                                hintText: 'voce@email.com',
                                hintStyle: TextStyle(color: Colors.white24),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Email inválido'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // Senha
                            const _Label('Senha'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              enabled: !_loading,
                              decoration: InputDecoration(
                                hintText: 'Mín. 8 chars, 1 maiúscula, 1 número',
                                hintStyle:
                                    const TextStyle(color: Colors.white24),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: _validatePassword,
                            ),

                            // Erro
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        const Color(0xFFEF4444).withAlpha(80),
                                  ),
                                ),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFC8181),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Botão
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Criar conta grátis',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Link login
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Já tem conta? ',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: _loading ? null : () => context.go('/login'),
                          child: Text(
                            'Entrar',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
    );
  }
}
