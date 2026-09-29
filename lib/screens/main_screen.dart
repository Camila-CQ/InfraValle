import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:app_report/screens/report_screen.dart';
import 'package:app_report/screens/ConsultReportScreen.dart';
import 'package:app_report/services/firebase_services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with TickerProviderStateMixin, RestorationMixin {
  final FirebaseService _firebaseService = FirebaseService();

  // ============================================================
  // ESTADO DE NAVEGACIÓN
  // ============================================================

  final RestorableInt _currentIndex = RestorableInt(0);

  final _reportKey = const PageStorageKey(
    'report_screen',
  );

  final _consultKey = const PageStorageKey(
    'consult_screen',
  );

  late final AnimationController _fadeCtrl =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  String get restorationId => 'main_screen';

  @override
  void restoreState(
    RestorationBucket? oldBucket,
    bool initialRestore,
  ) {
    registerForRestoration(
      _currentIndex,
      'nav_index',
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> _confirmAndSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            padding: const EdgeInsets.fromLTRB(
              24,
              26,
              24,
              20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F7F8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF168C95),
                    size: 32,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Cerrar sesión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF17343A),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  '¿Seguro que deseas salir de InfraValle?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.grey.shade700,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(true);
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 19,
                        ),
                        label: const Text(
                          'Salir',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF168C95),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await _firebaseService.signOut();

      if (context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/login',
        );
      }
    }
  }

  // ============================================================
  // CAMBIAR SECCIÓN
  // ============================================================

  void _onDestinationSelected(int idx) {
    if (_currentIndex.value == idx) {
      return;
    }

    setState(() {
      _currentIndex.value = idx;
    });

    _fadeCtrl
      ..reset()
      ..forward();
  }

  // ============================================================
  // ABRIR BÚSQUEDA REAL
  // ============================================================

  void _openSearch() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    showSearch(
      context: context,
      delegate: _ReportSearchDelegate(
        userId: user.uid,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth =
        MediaQuery.of(context).size.width;

    final bool isWide = screenWidth >= 980;

    final pages = <Widget>[
      PageStorage(
        bucket: PageStorageBucket(),
        key: _reportKey,
        child: const _KeepAlive(
          child: ReportScreen(),
          key: ValueKey('report'),
        ),
      ),

      PageStorage(
        bucket: PageStorageBucket(),
        key: _consultKey,
        child: const _KeepAlive(
          child: ConsultReportScreen(),
          key: ValueKey('consult'),
        ),
      ),
    ];

    final titles = [
      'Crear reporte',
      'Mis reportes',
    ];

    final body = FadeTransition(
      opacity: _fadeCtrl.drive(
        CurveTween(
          curve: Curves.easeInOut,
        ),
      ),
      child: IndexedStack(
        key: ValueKey(
          _currentIndex.value,
        ),
        index: _currentIndex.value,
        children: pages,
      ),
    );

    // ============================================================
    // APP BAR
    // ============================================================

    final appBar = AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleSpacing: isWide ? 24 : 18,

      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF27B3BB),
                  Color(0xFF168C95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Text(
                'InfraValle',
                style: TextStyle(
                  color: Color(0xFF17343A),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              Text(
                titles[_currentIndex.value],
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        // ========================================================
        // BUSCAR
        // ========================================================

        Container(
          margin: const EdgeInsets.only(
            right: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8F8),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: 'Buscar reportes',
            onPressed: _openSearch,
            icon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF168C95),
            ),
          ),
        ),

        // ========================================================
        // CERRAR SESIÓN
        // ========================================================

        Container(
          margin: const EdgeInsets.only(
            right: 14,
            left: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _confirmAndSignOut,
            icon: const Icon(
              Icons.logout_rounded,
              color: Color(0xFF555555),
            ),
          ),
        ),
      ],
    );

    // ============================================================
    // DESKTOP / WEB
    // ============================================================

    if (isWide) {
      return Scaffold(
        backgroundColor:
            const Color(0xFFF5F8F8),

        appBar: appBar,

        body: Row(
          children: [
            // ======================================================
            // SIDEBAR
            // ======================================================

            Container(
              width: 235,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),

              child: Column(
                children: [
                  const SizedBox(height: 20),

                  const _BrandHeader(),

                  const SizedBox(height: 20),

                  // Crear reporte
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    child: _DesktopNavigationItem(
                      icon: Icons
                          .add_circle_outline_rounded,
                      selectedIcon:
                          Icons.add_circle_rounded,
                      label: 'Crear reporte',
                      selected:
                          _currentIndex.value == 0,
                      onTap: () {
                        _onDestinationSelected(0);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Mis reportes
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    child: _DesktopNavigationItem(
                      icon: Icons
                          .description_outlined,
                      selectedIcon:
                          Icons.description_rounded,
                      label: 'Mis reportes',
                      selected:
                          _currentIndex.value == 1,
                      onTap: () {
                        _onDestinationSelected(1);
                      },
                    ),
                  ),

                  const Spacer(),

                  // =================================================
                  // INFORMACIÓN
                  // =================================================

                  Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Container(
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFF1F8F8,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color:
                                Color(0xFF168C95),
                            size: 22,
                          ),

                          const SizedBox(height: 9),

                          const Text(
                            'InfraValle',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              color:
                                  Color(0xFF17343A),
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Sistema ciudadano de reporte de infraestructura.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey
                                  .shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),

            // ======================================================
            // CONTENIDO
            // ======================================================

            Expanded(
              child: body,
            ),
          ],
        ),
      );
    }

    // ============================================================
    // MÓVIL
    // ============================================================

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F8F8),

      appBar: appBar,

      body: body,

      bottomNavigationBar:
          _buildMobileNavigation(),
    );
  }

  // ============================================================
  // NAVEGACIÓN MÓVIL
  // ============================================================

  Widget _buildMobileNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8,
          ),
          child: NavigationBar(
            selectedIndex:
                _currentIndex.value,

            onDestinationSelected:
                _onDestinationSelected,

            backgroundColor:
                Colors.transparent,

            elevation: 0,

            indicatorColor:
                const Color(0xFFDDF4F5),

            labelTextStyle:
                WidgetStateProperty.resolveWith(
              (states) {
                final selected =
                    states.contains(
                  WidgetState.selected,
                );

                return TextStyle(
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF168C95)
                      : Colors.grey.shade600,
                );
              },
            ),

            destinations: const [
              NavigationDestination(
                icon: Icon(
                  Icons
                      .add_circle_outline_rounded,
                ),
                selectedIcon: Icon(
                  Icons.add_circle_rounded,
                  color:
                      Color(0xFF168C95),
                ),
                label: 'Crear',
              ),

              NavigationDestination(
                icon: Icon(
                  Icons.description_outlined,
                ),
                selectedIcon: Icon(
                  Icons.description_rounded,
                  color:
                      Color(0xFF168C95),
                ),
                label: 'Mis reportes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// KEEP ALIVE
// ================================================================

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({
    required this.child,
    super.key,
  });

  @override
  State<_KeepAlive> createState() =>
      _KeepAliveState();
}

class _KeepAliveState
    extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ================================================================
// ENCABEZADO DE MARCA
// ================================================================

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF27B3BB),
                  Color(0xFF168C95),
                ],
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF27B3BB,
                  ).withOpacity(0.20),
                  blurRadius: 15,
                  offset:
                      const Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'InfraValle',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w800,
              color:
                  Color(0xFF17343A),
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'Reportes ciudadanos',
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// ITEM DE NAVEGACIÓN DESKTOP
// ================================================================

class _DesktopNavigationItem
    extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(14),

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),

          decoration: BoxDecoration(
            color: selected
                ? const Color(
                    0xFFE5F7F8,
                  )
                : Colors.transparent,

            borderRadius:
                BorderRadius.circular(14),
          ),

          child: Row(
            children: [
              Icon(
                selected
                    ? selectedIcon
                    : icon,

                color: selected
                    ? const Color(
                        0xFF168C95,
                      )
                    : Colors.grey.shade600,

                size: 23,
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(
                            0xFF168C95,
                          )
                        : Colors.grey.shade700,

                    fontSize: 14,

                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),

              if (selected)
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(0xFF168C95),
                    shape:
                        BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// BÚSQUEDA REAL DE REPORTES
// ================================================================

class _ReportSearchDelegate
    extends SearchDelegate<String> {
  final String userId;

  _ReportSearchDelegate({
    required this.userId,
  });

  @override
  String? get searchFieldLabel =>
      'Buscar mis reportes...';

  @override
  ThemeData appBarTheme(
    BuildContext context,
  ) {
    return Theme.of(context).copyWith(
      appBarTheme:
          const AppBarTheme(
        backgroundColor:
            Colors.white,
        foregroundColor:
            Color(0xFF17343A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      inputDecorationTheme:
          const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Colors.grey,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Limpiar',

          icon: const Icon(
            Icons.clear_rounded,
          ),

          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      tooltip: 'Volver',

      icon: const Icon(
        Icons.arrow_back_rounded,
      ),

      onPressed: () {
        close(context, '');
      },
    );
  }

  // ============================================================
  // NORMALIZAR TEXTO
  // ============================================================

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  // ============================================================
  // CONSULTAR REPORTES EN FIRESTORE
  // ============================================================

  Future<
      List<
          QueryDocumentSnapshot<
              Map<String, dynamic>>>> _searchReports() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('reports')
            .where(
              'userId',
              isEqualTo: userId,
            )
            .get();

    final searchText =
        _normalize(query);

    if (searchText.isEmpty) {
      return snapshot.docs;
    }

    final results =
        snapshot.docs.where((doc) {
      final data = doc.data();

      final description =
          _normalize(
        (data['description'] ?? '')
            .toString(),
      );

      final status =
          _normalize(
        (data['status'] ??
                'Pendiente')
            .toString(),
      );

      final adminDescription =
          _normalize(
        (data['adminDescription'] ??
                '')
            .toString(),
      );

      return description
              .contains(searchText) ||
          status.contains(searchText) ||
          adminDescription
              .contains(searchText);
    }).toList();

    // Más recientes primero.
    results.sort((a, b) {
      final aTimestamp =
          a.data()['timestamp'];

      final bTimestamp =
          b.data()['timestamp'];

      if (aTimestamp is Timestamp &&
          bTimestamp is Timestamp) {
        return bTimestamp.compareTo(
          aTimestamp,
        );
      }

      return 0;
    });

    return results;
  }

  // ============================================================
  // RESULTADOS
  // ============================================================

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    if (query.trim().isEmpty) {
      return const _EmptySearchState(
        icon: Icons.search_rounded,
        title:
            'Busca uno de tus reportes',
        message:
            'Escribe una palabra o frase para encontrar un reporte.',
      );
    }

    return FutureBuilder<
        List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>>(
      future: _searchReports(),

      builder: (
        context,
        snapshot,
      ) {
        // --------------------------------------------------------
        // CARGANDO
        // --------------------------------------------------------

        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(
              color:
                  Color(0xFF168C95),
            ),
          );
        }

        // --------------------------------------------------------
        // ERROR
        // --------------------------------------------------------

        if (snapshot.hasError) {
          return const _EmptySearchState(
            icon:
                Icons.error_outline_rounded,
            title:
                'No se pudo realizar la búsqueda',
            message:
                'Ocurrió un problema al consultar tus reportes. Inténtalo nuevamente.',
          );
        }

        final reports =
            snapshot.data ?? [];

        // --------------------------------------------------------
        // SIN RESULTADOS
        // --------------------------------------------------------

        if (reports.isEmpty) {
          return _EmptySearchState(
            icon:
                Icons.search_off_rounded,
            title:
                'No encontramos reportes',
            message:
                'No hay reportes que coincidan con "$query".',
          );
        }

        // --------------------------------------------------------
        // RESULTADOS
        // --------------------------------------------------------

        return ListView.builder(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            18,
            16,
            30,
          ),

          itemCount:
              reports.length,

          itemBuilder:
              (context, index) {
            final doc =
                reports[index];

            final data =
                doc.data();

            return _SearchReportCard(
              data: data,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SUGERENCIAS
  // ============================================================

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    if (query.trim().isEmpty) {
      return const _EmptySearchState(
        icon: Icons.search_rounded,
        title: 'Buscar reportes',
        message:
            'Puedes buscar por descripción, estado o comentario del administrador.',
      );
    }

    return buildResults(context);
  }
}

// ================================================================
// TARJETA DE RESULTADO
// ================================================================

class _SearchReportCard
    extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SearchReportCard({
    required this.data,
  });

  // ============================================================
  // COLOR DEL ESTADO
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    final normalized =
        status.toLowerCase();

    if (normalized.contains(
          'atendido',
        ) ||
        normalized.contains(
          'resuelto',
        ) ||
        normalized.contains(
          'finalizado',
        )) {
      return const Color(
        0xFF168C95,
      );
    }

    if (normalized.contains(
          'proceso',
        ) ||
        normalized.contains(
          'revision',
        ) ||
        normalized.contains(
          'revisión',
        )) {
      return const Color(
        0xFFD9822B,
      );
    }

    return const Color(
      0xFF777777,
    );
  }

  // ============================================================
  // TEXTO DEL ESTADO
  // ============================================================

  String _statusText() {
    final status =
        (data['status'] ??
                'Pendiente')
            .toString();

    if (status.trim().isEmpty) {
      return 'Pendiente';
    }

    return status;
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================

  String _formatDate() {
    final timestamp =
        data['timestamp'];

    if (timestamp is Timestamp) {
      final date =
          timestamp.toDate();

      final day =
          date.day.toString().padLeft(
                2,
                '0',
              );

      final month =
          date.month.toString().padLeft(
                2,
                '0',
              );

      final year =
          date.year.toString();

      return '$day/$month/$year';
    }

    return 'Fecha no disponible';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final description =
        (data['description'] ?? '')
            .toString();

    final imageUrl =
        (data['imageUrl'] ?? '')
            .toString();

    final status =
        _statusText();

    final statusColor =
        _statusColor(status);

    final adminDescription =
        (data['adminDescription'] ??
                '')
            .toString();

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.04),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(
          14,
        ),

        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [
            // ====================================================
            // FOTO
            // ====================================================

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),

              child: Container(
                width: 76,
                height: 76,

                color:
                    const Color(
                  0xFFF1F5F5,
                ),

                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,

                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Icon(
                                Icons
                                    .image_not_supported_outlined,
                                color:
                                    Colors.grey,
                                size: 28,
                              );
                            },
                          )
                        : const Icon(
                            Icons
                                .image_outlined,
                            color:
                                Colors.grey,
                            size: 28,
                          ),
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            // ====================================================
            // INFORMACIÓN
            // ====================================================

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    description.isEmpty
                        ? 'Reporte sin descripción'
                        : description,

                    maxLines: 3,

                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Color(
                        0xFF17343A,
                      ),
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 6,

                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              statusColor
                                  .withOpacity(
                            0.10,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Text(
                          status,

                          style:
                              TextStyle(
                            color:
                                statusColor,
                            fontSize: 11,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),

                      Text(
                        _formatDate(),

                        style:
                            TextStyle(
                          color:
                              Colors.grey
                                  .shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // ==================================================
                  // COMENTARIO ADMINISTRATIVO
                  // ==================================================

                  if (adminDescription
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Icon(
                          Icons
                              .comment_outlined,
                          size: 15,
                          color: Colors
                              .grey
                              .shade500,
                        ),

                        const SizedBox(
                          width: 5,
                        ),

                        Expanded(
                          child: Text(
                            adminDescription,

                            maxLines: 2,

                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// ESTADO VACÍO DE BÚSQUEDA
// ================================================================

class _EmptySearchState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptySearchState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          28,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 82,
              height: 82,

              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFE8F7F8),
                shape:
                    BoxShape.circle,
              ),

              child: Icon(
                icon,
                color:
                    const Color(
                  0xFF168C95,
                ),
                size: 40,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              title,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF17343A),
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize: 14,
                color:
                    Colors.grey.shade600,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}