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

  static const Color _primary = Color(0xFF27B3BB);
  static const Color _primaryDark = Color(0xFF168C95);
  static const Color _dark = Color(0xFF17343A);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // INICIAR SESIÓN
  // ============================================================

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

      final String? role =
          await _firebaseService.getUserRole(user);

      if (!mounted) return;

      if (role == 'admin') {
        Navigator.pushReplacementNamed(
          context,
          '/admin',
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          '/report',
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (_) {
      _showSnack(
        'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // REGISTRAR CIUDADANO
  // ============================================================

  Future<void> _registerUser() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user =
          await _firebaseService.registerWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        'Nombre de Usuario',
        'user',
      );

      if (user != null) {
        // Firebase inicia sesión automáticamente
        // al crear la cuenta. Cerramos esa sesión
        // para permanecer en el Login.
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await _showRegistrationSuccessDialog(
          title: '¡Registro exitoso!',
          message:
              'El ciudadano fue registrado correctamente.',
        );
      } else {
        _showSnack('Error al registrarse');
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (_) {
      _showSnack(
        'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // REGISTRAR ADMINISTRADOR
  // ============================================================

  Future<void> _registerAdmin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user =
          await _firebaseService.registerWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        'Nombre de Admin',
        'admin',
      );

      if (user != null) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        await _showRegistrationSuccessDialog(
          title: '¡Registro exitoso!',
          message:
              'El administrador fue registrado correctamente.',
        );
      } else {
        _showSnack(
          'Error al registrarse como administrador',
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (_) {
      _showSnack(
        'Ocurrió un error inesperado. Intenta de nuevo.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // MENSAJE DE REGISTRO EXITOSO
  // ============================================================

  Future<void> _showRegistrationSuccessDialog({
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                24,
                28,
                24,
                22,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.green.shade700,
                      size: 54,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: _dark,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.check_rounded,
                      ),
                      label: const Text(
                        'Entendido',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // RECUPERAR CONTRASEÑA
  // ============================================================

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showSnack(
        'Escribe tu correo para enviarte el enlace de recuperación.',
      );

      _emailFocus.requestFocus();
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(
        email: email,
      );

      _showSnack(
        'Te enviamos un enlace para recuperar tu contraseña.',
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(_friendlyAuthError(e));
    } catch (_) {
      _showSnack(
        'No pudimos enviar el correo. Intenta más tarde.',
      );
    }
  }

  // ============================================================
  // MENSAJES
  // ============================================================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(msg),
      ),
    );
  }

  String _friendlyAuthError(
    FirebaseAuthException e,
  ) {
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

  // ============================================================
  // VALIDACIÓN DE CORREO
  // ============================================================

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();

    if (value.isEmpty) {
      return 'Escribe tu correo';
    }

    final emailRegex = RegExp(
      r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Correo inválido';
    }

    return null;
  }

  // ============================================================
  // VALIDACIÓN DE CONTRASEÑA
  // ============================================================

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();

    if (value.isEmpty) {
      return 'Escribe tu contraseña';
    }

    if (value.length < 6) {
      return 'Mínimo 6 caracteres';
    }

    return null;
  }

  // ============================================================
  // CAMPO DE TEXTO
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: _primaryDark,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF6FAFA),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: _primary,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.red.shade300,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isDesktop = size.width >= 900;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ----------------------------------------------------
          // FONDO
          // ----------------------------------------------------

          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),

          // Degradado sobre la imagen
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xCC062F35),
                  Color(0x99106D74),
                  Color(0xB3000000),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------
          // CONTENIDO
          // ----------------------------------------------------

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1050,
                  ),
                  child: isDesktop
                      ? _buildDesktopLayout()
                      : _buildMobileLayout(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISEÑO PARA COMPUTADOR
  // ============================================================

  Widget _buildDesktopLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // --------------------------------------------------
            // PANEL IZQUIERDO
            // --------------------------------------------------

            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _primary,
                      _primaryDark,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: _primaryDark,
                        size: 44,
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'InfraValle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Reporta, consulta y da seguimiento a los problemas de infraestructura de tu comunidad.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 34),

                    _buildFeature(
                      Icons.report_problem_outlined,
                      'Reportes ciudadanos',
                    ),

                    const SizedBox(height: 16),

                    _buildFeature(
                      Icons.photo_camera_outlined,
                      'Evidencia fotográfica',
                    ),

                    const SizedBox(height: 16),

                    _buildFeature(
                      Icons.location_on_outlined,
                      'Ubicación del reporte',
                    ),
                  ],
                ),
              ),
            ),

            // --------------------------------------------------
            // PANEL DERECHO - LOGIN
            // --------------------------------------------------

            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 55,
                  vertical: 48,
                ),
                child: _buildLoginForm(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISEÑO PARA CELULAR
  // ============================================================

  Widget _buildMobileLayout() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        30,
        24,
        24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: _buildLoginForm(),
    );
  }

  // ============================================================
  // FORMULARIO PRINCIPAL
  // ============================================================

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        // Encabezado
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  _primary,
                  _primaryDark,
                ],
              ),
              borderRadius:
                  BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Bienvenida/o a InfraValle',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _dark,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Inicia sesión para continuar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 30),

        // ------------------------------------------------------
        // FORMULARIO
        // ------------------------------------------------------

        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                keyboardType:
                    TextInputType.emailAddress,
                textInputAction:
                    TextInputAction.next,
                validator: _validateEmail,
                onFieldSubmitted: (_) {
                  _passwordFocus.requestFocus();
                },
                decoration: _inputDecoration(
                  label: 'Correo electrónico',
                  icon: Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                textInputAction:
                    TextInputAction.done,
                validator: _validatePassword,
                onFieldSubmitted: (_) {
                  _signIn();
                },
                decoration: _inputDecoration(
                  label: 'Contraseña',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons
                              .visibility_off_outlined,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ------------------------------------------------------
        // RECUPERAR CONTRASEÑA
        // ------------------------------------------------------

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
                _isLoading ? null : _resetPassword,
            style: TextButton.styleFrom(
              foregroundColor: _primaryDark,
            ),
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ------------------------------------------------------
        // INICIAR SESIÓN
        // ------------------------------------------------------

        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed:
                _isLoading ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryDark,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor:
                  _primaryDark.withOpacity(0.3),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(15),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login_rounded,
                        size: 21,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 25),

        // ------------------------------------------------------
        // SEPARADOR
        // ------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey.shade300,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              child: Text(
                'Crear una cuenta',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey.shade300,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ------------------------------------------------------
        // REGISTROS
        // ------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _registerUser,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      _primaryDark,
                  side: const BorderSide(
                    color: _primary,
                    width: 1.5,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 22,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Ciudadano',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _registerAdmin,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      _primaryDark,
                  side: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 22,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Administrador',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        // ------------------------------------------------------
        // PIE
        // ------------------------------------------------------

        Text(
          'InfraValle • Reportes de infraestructura',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          'Versión 1.0.0',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ELEMENTOS DEL PANEL IZQUIERDO
  // ============================================================

  Widget _buildFeature(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 23,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}