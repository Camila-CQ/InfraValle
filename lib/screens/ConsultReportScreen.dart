import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'details_report_ciudadano.dart';

class ConsultReportScreen extends StatefulWidget {
  const ConsultReportScreen({super.key});

  @override
  State<ConsultReportScreen> createState() => _ConsultReportScreenState();
}

class _ConsultReportScreenState extends State<ConsultReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _orderByDate = true;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final col = _firestore.collection('reports');
    if (_orderByDate) {
      // Si algún documento no tiene 'timestamp', no aparecerá en esta query.
      // Puedes alternar con el botón del AppBar.
      return col.orderBy('timestamp', descending: true).snapshots();
    }
    return col.snapshots();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted) setState(() {});
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return 'Sin fecha';
    final dt = ts.toDate();
    // Intl.defaultLocale = 'es'; // opcional si usas locales
    return DateFormat('dd/MM/yyyy • HH:mm').format(dt);
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('mora')) return Colors.redAccent;
    if (s.contains('pend')) return Colors.orangeAccent;
    if (s.contains('resuelto') || s.contains('cerr') || s.contains('complet')) return Colors.green;
    if (s.contains('proceso') || s.contains('asign')) return Colors.blueAccent;
    return Colors.grey;
  }

  String _normalizeImageUrl(String url) {
    var u = url.trim();
    u = u.replaceAll('&amp;', '&'); // ← clave para tu caso
    if (u.startsWith('http://')) u = u.replaceFirst('http://', 'https://');
    return u;
  }

  String _locationText(dynamic location) {
    if (location is GeoPoint) {
      return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    }
    return 'Ubicación no disponible';
  }

  Future<void> _openMaps(dynamic location) async {
    if (location is GeoPoint) {
      final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.platformDefault);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const colorSeed = Color.fromARGB(255, 110, 197, 159);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Infraestructura'),
        backgroundColor: colorSeed,
        actions: [
          IconButton(
            tooltip: _orderByDate ? 'Quitar orden por fecha' : 'Ordenar por fecha',
            icon: Icon(_orderByDate ? Icons.schedule : Icons.list),
            onPressed: () => setState(() => _orderByDate = !_orderByDate),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorSeed.withOpacity(0.12), Colors.lightBlueAccent.withOpacity(0.10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),
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
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay reportes aún', style: TextStyle(fontSize: 16)),
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
                  final statusRaw = (data['status'] ?? 'Pendiente').toString();
                  final status = statusRaw == 'en mora' ? 'En Mora' : statusRaw;
                  final ts = data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : null;
                  final imgRaw = (data['imageUrl'] ?? '').toString();
                  final imageUrl = imgRaw.isNotEmpty ? _normalizeImageUrl(imgRaw) : '';
                  final location = data['location']; // GeoPoint? según tus docs

                  return _CitizenReportCard(
                    reportId: doc.id,
                    description: description,
                    status: status,
                    statusColor: _statusColor(status),
                    dateText: _formatDate(ts),
                    imageUrl: imageUrl,
                    location: location,
                    onOpenMap: () => _openMaps(location),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailsReportCiudadano(reportId: doc.id),
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

class _CitizenReportCard extends StatelessWidget {
  final String reportId;
  final String description;
  final String status;
  final Color statusColor;
  final String dateText;
  final String imageUrl;
  final dynamic location; // GeoPoint? u otro
  final VoidCallback onOpenMap;
  final VoidCallback onTap;

  const _CitizenReportCard({
    required this.reportId,
    required this.description,
    required this.status,
    required this.statusColor,
    required this.dateText,
    required this.imageUrl,
    required this.location,
    required this.onOpenMap,
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
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumbnail(imageUrl: imageUrl),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Descripción
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),

                        // Fecha
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(dateText, style: subtitleStyle),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Ubicación + botón mapa
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _humanLocation(location),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: subtitleStyle,
                              ),
                            ),
                            if (location is GeoPoint)
                              TextButton.icon(
                                onPressed: onOpenMap,
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text('Ver mapa'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 36),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Estado
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text(
                              status,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: statusColor,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),

          // Ícono decorativo en la esquina
          Positioned(
            right: 10,
            top: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.report_gmailerrorred_outlined, color: Colors.orange, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _humanLocation(dynamic loc) {
    if (loc is GeoPoint) {
      return '${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}';
    }
    return 'Ubicación no disponible';
  }
}

class _Thumbnail extends StatelessWidget {
  final String imageUrl;
  const _Thumbnail({required this.imageUrl});

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
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 28),
        ),
      );
    }

    // Log para depurar si falla
    // ignore: avoid_print
    print('🖼️ Cargando imagen (civil): $imageUrl');

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // ignore: avoid_print
            print('❌ Error cargando imagen (civil): $error');
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: size,
                height: size,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
              ),
            );
          },
        ),
      ),
    );
  }
}