import 'package:flutter/material.dart';
import 'package:app_report/screens/report_screen.dart';
import 'package:app_report/screens/ConsultReportScreen.dart';
import 'package:app_report/services/firebase_services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin, RestorationMixin {
  final FirebaseService _firebaseService = FirebaseService();

  // Restauración de estado (índice de navegación)
  final RestorableInt _currentIndex = RestorableInt(0);

  // Keys para preservar estado de cada sección
  final _reportKey = const PageStorageKey('report_screen');
  final _consultKey = const PageStorageKey('consult_screen');

  // Control opcional para animaciones entre páginas
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  String get restorationId => 'main_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_currentIndex, 'nav_index');
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _currentIndex.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas salir de la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _firebaseService.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _onDestinationSelected(int idx) {
    setState(() => _currentIndex.value = idx);
    _fadeCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    final pages = <Widget>[
      // Crear Reporte
      PageStorage(
        bucket: PageStorageBucket(),
        child: const _KeepAlive(child: ReportScreen(), key: ValueKey('report')),
        key: _reportKey,
      ),
      // Consultar Reportes
      PageStorage(
        bucket: PageStorageBucket(),
        child: const _KeepAlive(child: ConsultReportScreen(), key: ValueKey('consult')),
        key: _consultKey,
      ),
    ];

    final titles = ['Crear reporte', 'Consultar reportes'];

    final body = FadeTransition(
      opacity: _fadeCtrl.drive(CurveTween(curve: Curves.easeInOut)),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: IndexedStack(
          key: ValueKey(_currentIndex.value),
          index: _currentIndex.value,
          children: pages,
        ),
      ),
    );

    final appBar = AppBar(
      elevation: 0,
      title: Text(
        'Reporte de Infraestructura',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
      ),
      backgroundColor: const Color.fromARGB(255, 183, 231, 194),
      actions: [
        IconButton(
          tooltip: 'Buscar',
          onPressed: () {
            showSearch(context: context, delegate: _ReportSearchDelegate());
          },
          icon: const Icon(Icons.search_rounded, color: Colors.black87),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Cerrar sesión',
          icon: const Icon(Icons.logout, color: Colors.black87),
          onPressed: _confirmAndSignOut,
        ),
        const SizedBox(width: 8),
      ],
    );

    // --- Responsive Scaffold ---
    if (isWide) {
      // WEB/DESKTOP: NavigationRail + AppBar
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 232, 246, 236),
                border: Border(
                  right: BorderSide(color: Color(0xFFE0E0E0)),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: NavigationRail(
                selectedIndex: _currentIndex.value,
                onDestinationSelected: _onDestinationSelected,
                labelType: NavigationRailLabelType.selected,
                groupAlignment: -1.0,
                backgroundColor: const Color.fromARGB(255, 232, 246, 236),
                leading: const _BrandHeader(),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.add_circle_outline),
                    selectedIcon: Icon(Icons.add_circle, color: Colors.green),
                    label: Text('Crear'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt, color: Colors.green),
                    label: Text('Consultar'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      // MÓVIL: NavigationBar + AppBar
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex.value,
          onDestinationSelected: _onDestinationSelected,
          elevation: 1,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Crear',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Consultar',
            ),
          ],
        ),
      );
    }
  }
}

// --------- Widgets utilitarios ---------

/// Mantiene viva la subpantalla (no se desmonta al cambiar de pestaña)
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child, super.key});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Encabezado marca/logo para NavigationRail (opcional)
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green[400],
            child: const Icon(Icons.construction, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'InfraValle',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

// --------- Búsqueda (placeholder/ejemplo) ---------

class _ReportSearchDelegate extends SearchDelegate<String> {
  @override
  String? get searchFieldLabel => 'Buscar reportes...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Aquí puedes navegar a ConsultReportScreen con un filtro por query,
    // o disparar un provider/stream. De momento mostramos un placeholder.
    return Center(
      child: Text('Resultados para: $query'),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Sugerencias rápidas (recientes, populares, etc.)
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Baches en Calle 12'),
          onTap: () => query = 'Baches en Calle 12',
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Poste caído'),
          onTap: () => query = 'Poste caído',
        ),
      ],
    );
  }
}
