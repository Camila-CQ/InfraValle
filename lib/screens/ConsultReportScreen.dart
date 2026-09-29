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
    final collection = _firestore.collection('reports');

    if (_orderByDate) {
      return collection
          .orderBy('timestamp', descending: true)
          .snapshots();
    }

    return collection.snapshots();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() {});
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Sin fecha';
    }

    final date = timestamp.toDate();

    return DateFormat('dd/MM/yyyy • HH:mm').format(date);
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase().trim();

    if (normalized.contains('mora')) {
      return Colors.red;
    }

    if (normalized.contains('pend')) {
      return Colors.orange;
    }

    if (normalized.contains('resuelto') ||
        normalized.contains('cerr') ||
        normalized.contains('complet')) {
      return Colors.green;
    }

    if (normalized.contains('proceso') ||
        normalized.contains('asign')) {
      return Colors.blue;
    }

    return Colors.grey;
  }

  IconData _statusIcon(String status) {
    final normalized = status.toLowerCase().trim();

    if (normalized.contains('mora')) {
      return Icons.warning_amber_rounded;
    }

    if (normalized.contains('pend')) {
      return Icons.schedule_rounded;
    }

    if (normalized.contains('resuelto') ||
        normalized.contains('cerr') ||
        normalized.contains('complet')) {
      return Icons.check_circle_outline_rounded;
    }

    if (normalized.contains('proceso') ||
        normalized.contains('asign')) {
      return Icons.autorenew_rounded;
    }

    return Icons.info_outline_rounded;
  }

  String _normalizeImageUrl(String url) {
    var normalized = url.trim();

    normalized = normalized.replaceAll('&amp;', '&');

    if (normalized.startsWith('http://')) {
      normalized = normalized.replaceFirst(
        'http://',
        'https://',
      );
    }

    return normalized;
  }

  Future<void> _openMaps(dynamic location) async {
    if (location is! GeoPoint) {
      return;
    }

    final url =
        'https://www.google.com/maps/search/?api=1&query='
        '${location.latitude},${location.longitude}';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(
        url,
        mode: LaunchMode.platformDefault,
      );
    }
  }

  String _locationText(dynamic location) {
    if (location is GeoPoint) {
      return '${location.latitude.toStringAsFixed(5)}, '
          '${location.longitude.toStringAsFixed(5)}';
    }

    return 'Ubicación no disponible';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6EC59F);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,

        titleSpacing: 20,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mis reportes',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Consulta y seguimiento',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: _orderByDate
                ? 'Mostrar sin ordenar'
                : 'Ordenar por fecha',
            icon: Icon(
              _orderByDate
                  ? Icons.sort_rounded
                  : Icons.view_list_rounded,
            ),
            onPressed: () {
              setState(() {
                _orderByDate = !_orderByDate;
              });
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3FAF7),
              Color(0xFFF8FAFC),
            ],
          ),
        ),

        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: _refresh,

          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream(),

            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message:
                      'No fue posible cargar los reportes.\n\n'
                      '${snapshot.error}',
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const _EmptyReportsState();
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  30,
                ),
                itemCount: docs.length,

                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();

                  final description =
                      (data['description'] ??
                              'Sin descripción')
                          .toString();

                  final statusRaw =
                      (data['status'] ??
                              'Pendiente')
                          .toString();

                  final status =
                      statusRaw.toLowerCase() == 'en mora'
                          ? 'En Mora'
                          : statusRaw;

                  final timestamp =
                      data['timestamp'] is Timestamp
                          ? data['timestamp'] as Timestamp
                          : null;

                  final imageRaw =
                      (data['imageUrl'] ?? '')
                          .toString();

                  final imageUrl = imageRaw.isNotEmpty
                      ? _normalizeImageUrl(imageRaw)
                      : '';

                  final location = data['location'];

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 14,
                    ),

                    child: _CitizenReportCard(
                      reportId: doc.id,
                      description: description,
                      status: status,
                      statusColor: _statusColor(status),
                      statusIcon: _statusIcon(status),
                      dateText: _formatDate(timestamp),
                      imageUrl: imageUrl,
                      location: location,

                      onOpenMap: () {
                        _openMaps(location);
                      },

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetailsReportCiudadano(
                              reportId: doc.id,
                            ),
                          ),
                        );
                      },
                    ),
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

// ============================================================
// TARJETA DEL REPORTE
// ============================================================

class _CitizenReportCard extends StatelessWidget {
  final String reportId;
  final String description;
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final String dateText;
  final String imageUrl;
  final dynamic location;
  final VoidCallback onOpenMap;
  final VoidCallback onTap;

  const _CitizenReportCard({
    required this.reportId,
    required this.description,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.dateText,
    required this.imageUrl,
    required this.location,
    required this.onOpenMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,

      shadowColor: Colors.black.withOpacity(0.08),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  _ReportThumbnail(
                    imageUrl: imageUrl,
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Expanded(
                              child: Text(
                                'Reporte de infraestructura',
                                maxLines: 2,
                                overflow:
                                    TextOverflow.ellipsis,

                                style: theme
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight:
                                          FontWeight.w700,
                                      color:
                                          const Color(
                                        0xFF202A2A,
                                      ),
                                    ),
                              ),
                            ),

                            const SizedBox(width: 6),

                            const Icon(
                              Icons
                                  .arrow_forward_ios_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),

                        const SizedBox(height: 7),

                        Text(
                          description,
                          maxLines: 3,
                          overflow:
                              TextOverflow.ellipsis,

                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                height: 1.35,
                                color:
                                    Colors.grey[700],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                height: 1,
                color: Colors.grey.shade200,
              ),

              const SizedBox(height: 12),

              // FECHA
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(6),

                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF6EC59F,
                      ).withOpacity(0.10),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),

                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: Color(0xFF4FA882),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 9),

              // UBICACIÓN
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,

                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(6),

                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),

                    child: const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Colors.redAccent,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _humanLocation(location),
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),

                  if (location is GeoPoint)
                    TextButton(
                      onPressed: onOpenMap,

                      style: TextButton.styleFrom(
                        foregroundColor:
                            const Color(
                          0xFF4FA882,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 8,
                        ),
                        minimumSize:
                            const Size(0, 34),
                      ),

                      child: const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 17,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Mapa',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ESTADO
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),

                    decoration: BoxDecoration(
                      color: statusColor
                          .withOpacity(0.10),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: statusColor
                            .withOpacity(0.20),
                      ),
                    ),

                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,

                      children: [
                        Icon(
                          statusIcon,
                          size: 17,
                          color: statusColor,
                        ),

                        const SizedBox(width: 6),

                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight:
                                FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  Text(
                    'Ver detalles',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),

                  const SizedBox(width: 4),

                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _humanLocation(dynamic loc) {
    if (loc is GeoPoint) {
      return '${loc.latitude.toStringAsFixed(5)}, '
          '${loc.longitude.toStringAsFixed(5)}';
    }

    return 'Ubicación no disponible';
  }
}

// ============================================================
// MINIATURA DE LA FOTO
// ============================================================

class _ReportThumbnail extends StatelessWidget {
  final String imageUrl;

  const _ReportThumbnail({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 82;

    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,

        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),

        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),

      child: SizedBox(
        width: size,
        height: size,

        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,

          loadingBuilder:
              (context, child, progress) {
            if (progress == null) {
              return child;
            }

            return Container(
              color: Colors.grey.shade100,

              alignment: Alignment.center,

              child: SizedBox(
                width: 22,
                height: 22,

                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,

                  value: progress
                              .expectedTotalBytes !=
                          null
                      ? progress
                              .cumulativeBytesLoaded /
                          progress
                              .expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },

          errorBuilder:
              (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade100,

              alignment: Alignment.center,

              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 30,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// SIN REPORTES
// ============================================================

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(
          height:
              MediaQuery.of(context).size.height *
                  0.25,
        ),

        Center(
          child: Container(
            width: 92,
            height: 92,

            decoration: BoxDecoration(
              color: const Color(0xFF6EC59F)
                  .withOpacity(0.10),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.assignment_outlined,
              size: 45,
              color: Color(0xFF6EC59F),
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'No hay reportes todavía',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF263333),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 40,
          ),

          child: Text(
            'Cuando realices un reporte de infraestructura, aparecerá aquí para que puedas consultar su estado.',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey[600],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(
          height:
              MediaQuery.of(context).size.height *
                  0.25,
        ),

        Center(
          child: Container(
            width: 90,
            height: 90,

            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Colors.redAccent,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'No se pudieron cargar los reportes',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF263333),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 30,
          ),

          child: Text(
            message,
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey[600],
            ),
          ),
        ),

        const SizedBox(height: 25),

        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },

            icon: const Icon(
              Icons.arrow_back_rounded,
            ),

            label: const Text(
              'Volver',
            ),
          ),
        ),
      ],
    );
  }
}