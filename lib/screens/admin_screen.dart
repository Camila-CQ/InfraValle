import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'report_details_screen.dart';
import 'package:app_report/services/firebase_services.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _orderByDate = true; // puedes alternar si quieres

  Future<void> _signOut() async {
    await _firebaseService.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Stream de reportes (si todos tienen timestamp, usamos orderBy; si no, fallback)
  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream() {
    final col = FirebaseFirestore.instance.collection('reports');
    if (_orderByDate) {
      // Si alguno no tiene timestamp, Firestore excluirá ese doc en la query con orderBy.
      // Si ves que "faltan", cambia _orderByDate a false o asegúrate de setear el campo.
      return col.orderBy('timestamp', descending: true).snapshots();
    } else {
      return col.snapshots();
    }
  }

  Future<void> _refresh() async {
    // Para RefreshIndicator basta con esperar un tick y setState
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() {});
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('mora')) return Colors.redAccent;
    if (s.contains('pend')) return Colors.orangeAccent;
    if (s.contains('cerr') || s.contains('resuelto') || s.contains('complet'))
      return Colors.green;
    if (s.contains('proceso') || s.contains('asign')) return Colors.blueAccent;
    return Colors.grey;
    // Ajusta a tus estados reales: "En Mora", "Pendiente", "En Proceso", "Cerrado", etc.
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final dt = ts.toDate();
    // Formato corto y claro para web/es
    return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorSeed = const Color(0xFF27B3BB); // tu color acento

    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        backgroundColor: colorSeed,
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            tooltip: 'Ordenar por fecha',
            icon: Icon(_orderByDate ? Icons.schedule : Icons.list),
            onPressed: () => setState(() => _orderByDate = !_orderByDate),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorSeed.withOpacity(0.10),
              Colors.lightBlueAccent.withOpacity(0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reportsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error al cargar reportes:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No hay reportes para mostrar.',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();

                  final description = (data['description'] ?? 'Sin descripción').toString();
                  final userId = (data['userId'] ?? '—').toString();
                  final imageUrl = (data['imageUrl'] ?? '').toString();
                  final ts = data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : null;
                  final statusRaw = (data['status'] ?? 'Pendiente').toString();
                  final status = statusRaw == 'en mora' ? 'En Mora' : statusRaw;

                  return _ReportAdminCard(
                    reportId: doc.id,
                    description: description,
                    userId: userId,
                    imageUrl: imageUrl,
                    dateText: _formatDate(ts),
                    status: status,
                    statusColor: _statusColor(status),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailsScreen(reportId: doc.id),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReportAdminCard extends StatelessWidget {
  final String reportId;
  final String description;
  final String userId;
  final String imageUrl;
  final String dateText;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  const _ReportAdminCard({
    required this.reportId,
    required this.description,
    required this.userId,
    required this.imageUrl,
    required this.dateText,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700]);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Stack(
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  _ReportThumbnail(imageUrl: imageUrl),

                  const SizedBox(width: 12),

                  // Contenido
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título / Descripción principal
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),

                        // Línea de metadatos: fecha + userId
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(dateText, style: subtitleStyle),
                            const SizedBox(width: 12),
                            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                userId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Chips de estado
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Chip(
                              label: Text(
                                status,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: statusColor,
                              padding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            Chip(
                              label: Text('#$reportId', overflow: TextOverflow.ellipsis),
                              avatar: const Icon(Icons.tag, size: 18),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Flecha
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),

          // 🛠️ Logito de reparación en la esquina superior derecha del card
          Positioned(
            right: 10,
            top: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.build_rounded, // logito de reparación
                color: Color(0xFF27B3BB),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  final String imageUrl;
  const _ReportThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const double size = 66;

    if (imageUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 28),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
        ),
      ),
    );
  }
}