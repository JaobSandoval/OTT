import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;

  String? _error;

  @override
  void initState() {
    super.initState();
    _userCtrl = TextEditingController(
      text: AppConfig.useExelAuth ? '' : 'demo@exel.com.mx',
    );
    _passCtrl = TextEditingController(
      text: AppConfig.useExelAuth ? '' : 'demo',
    );
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final err = await widget.auth.login(
      usernameOrEmail: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (err != null && mounted) {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Iniciar sesión',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _userCtrl,
                      decoration: InputDecoration(
                        labelText: AppConfig.useExelAuth ? 'Usuario' : 'Correo / Usuario',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: AppConfig.useExelAuth
                          ? TextInputType.text
                          : TextInputType.emailAddress,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: !AppConfig.useExelAuth,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                    ],
                    ListenableBuilder(
                      listenable: widget.auth,
                      builder: (context, _) {
                        return FilledButton(
                          onPressed: widget.auth.isLoading ? null : _submit,
                          child: widget.auth.isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!AppConfig.useExelAuth) ...[
                      Text(
                        'Demo: demo@exel.com.mx / demo',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        'Usuario y contraseña Exel. Se registra el dispositivo para notificaciones.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
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

