import 'package:app_report/screens/ConsultReportScreen.dart';
import 'package:app_report/screens/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:app_report/services/firebase_services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService(); 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> signOut(BuildContext context) async {
    await _firebaseService.signOut();
    Navigator.pushReplacementNamed(context, '/login'); // Navegar a la pantalla de login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte de Infraestructura'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Crear Reporte'),
            Tab(text: 'Consultar Reportes'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => signOut(context), 
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ReportScreen(), // Crear Reporte
          ConsultReportScreen(), // Consultar Reportes
        ],
      ),
    );
  }
}
