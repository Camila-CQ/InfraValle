import 'package:flutter/material.dart';
import 'package:app_report/services/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Colores base (puedes cambiarlos a tu paleta)
  static const Color _primary = Color(0xFF27B3BB); // tu color acento
  static const Color _titleColor = Colors.black;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // -------------------- AUTH ACTIONS --------------------

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final user = await _firebaseService.loginWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (user == null) {
        _showSnack('Error al iniciar sesión');
        return;
      }

      final String? role = await _firebaseService.getUserRole(user);
      if (role == 'admin') {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/report');
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (e) {
      _showSnack('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final user = await _firebaseService.registerWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        "Nombre de Usuario",
        "user",
      );

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/report');
      } else {
        _showSnack('Error al registrarse');
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (e) {
      _showSnack('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerAdmin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final user = await _firebaseService.registerWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        "Nombre de Admin",
        "admin",
      );

      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        _showSnack('Error al registrarse como administrador');
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (e) {
      _showSnack('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnack('Escribe tu correo para enviarte el enlace de recuperación.');
      _emailFocus.requestFocus();
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack('Te enviamos un enlace para recuperar tu contraseña.');
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (_) {
      _showSnack('No pudimos enviar el correo. Intenta más tarde.');
    }
  }

  // -------------------- UI HELPERS --------------------

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Este usuario está deshabilitado.';
      case 'user-not-found':
        return 'Usuario no encontrado.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'operation-not-allowed':
        return 'Este método de acceso no está habilitado.';
      default:
        return 'Error de autenticación: ${e.code}';
    }
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Escribe tu correo';
    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value)) return 'Correo inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Escribe tu contraseña';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  // -------------------- BUILD --------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 720;

    final cardWidth = isWide ? 520.0 : size.width * 0.9;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
        
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Capa oscura para contraste
          Container(color: Colors.black.withOpacity(0.35)),

          // Contenido
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Título
                        Text(
                          'Bienvenida/o a InfraValle',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isWide ? 34 : 26,
                            fontWeight: FontWeight.bold,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Inicia sesión o crea tu cuenta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isWide ? 18 : 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Formulario
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                                decoration: InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Botón principal: Iniciar sesión
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Iniciar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Botones secundarios: Registrar usuario / admin
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : _registerUser,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Registrar Usuario'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _registerAdmin,
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Registrar Admin'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),
                        const Divider(height: 28),
                        const SizedBox(height: 6),

                        // Pie de página / créditos o versión
                        Text(
                          'v1.0.0 • Reportes De Infraestructura',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}