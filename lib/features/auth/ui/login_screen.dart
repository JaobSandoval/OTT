import 'package:exel_ott/core/auth/auth_controller.dart';
import 'package:exel_ott/core/config/app_config.dart';
import 'package:exel_ott/core/config/app_runtime_endpoints.dart';
import 'package:exel_ott/core/debug/debug_terminal_gate.dart';
import 'package:exel_ott/core/debug/technical_log_store.dart';
import 'package:exel_ott/core/theme/app_colors.dart';
import 'package:exel_ott/core/theme/app_decorations.dart';
import 'package:exel_ott/core/utils/external_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _obscurePassword = true;

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

    if (DebugTerminalGate.matches(
      user: _userCtrl.text.trim(),
      pass: _passCtrl.text,
    )) {
      TechnicalLogStore.instance.enable();
      TechnicalLogStore.instance.info(
        'SYSTEM',
        'Terminal técnica activada',
        fields: {
          'plataforma': Theme.of(context).platform.name,
        },
      );
      return;
    }

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
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: AppDecorations.brandGradient,
                ),
                padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 36),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/x.png',
                      height: 72,
                      fit: BoxFit.contain,
                      color: Colors.white,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppConfig.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tu acceso a XLStore',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: AppDecorations.softCard(
                          radius: AppDecorations.radiusXl,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Iniciar sesión',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _userCtrl,
                                decoration: InputDecoration(
                                  hintText: AppConfig.useExelAuth
                                      ? 'Usuario'
                                      : 'Correo / Usuario',
                                  prefixIcon:
                                      const Icon(Icons.person_outline_rounded),
                                ),
                                keyboardType: AppConfig.useExelAuth
                                    ? TextInputType.text
                                    : TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                autocorrect: !AppConfig.useExelAuth,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Contraseña',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Mostrar contraseña'
                                        : 'Ocultar contraseña',
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Requerido'
                                    : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (AppConfig.useExelAuth)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => openInAppUrl(
                                      context,
                                      AppRuntimeEndpoints
                                          .instance.urlHazOlvidadoTuContrasena,
                                    ),
                                    child: const Text('¿Olvidaste tu contraseña?'),
                                  ),
                                ),
                              if (_error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.onErrorContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ListenableBuilder(
                                listenable: widget.auth,
                                builder: (context, _) {
                                  return FilledButton(
                                    onPressed:
                                        widget.auth.isLoading ? null : _submit,
                                    child: widget.auth.isLoading
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Entrar'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (AppConfig.useExelAuth) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Usuario y contraseña de la XLStore',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () => openInAppUrl(
                            context,
                            AppRuntimeEndpoints.instance.urlAltaDeCliente,
                          ),
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        Text(
                          'Demo: demo@exel.com.mx / demo',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
