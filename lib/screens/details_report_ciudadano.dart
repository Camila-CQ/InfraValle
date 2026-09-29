import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ============================================================
// COLORES INFRAVALLE
// ============================================================

const Color kPrimaryColor = Color(0xFF27B3BB);
const Color kPrimaryDark = Color(0xFF168F98);
const Color kPrimaryLight = Color(0xFFE7F7F8);
const Color kBackgroundColor = Color(0xFFF5F8F9);
const Color kTextColor = Color(0xFF203638);

// ============================================================
// DETALLE DEL REPORTE CIUDADANO
// ============================================================

class DetailsReportCiudadano extends StatelessWidget {
  final String reportId;

  const DetailsReportCiudadano({
    super.key,
    required this.reportId,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      backgroundColor: kBackgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,

        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalle del reporte',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Información de la incidencia',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),

      // ========================================================
      // STREAM EN TIEMPO REAL
      // ========================================================

      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('reports')
            .doc(reportId)
            .snapshots(),

        builder: (context, snapshot) {
          // ----------------------------------------------------
          // CARGANDO
          // ----------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: kPrimaryColor,
              ),
            );
          }

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (snapshot.hasError) {
            return _ErrorState(
              message:
                  'No fue posible cargar el reporte.\n\n'
                  '${snapshot.error}',
            );
          }

          // ----------------------------------------------------
          // NO EXISTE
          // ----------------------------------------------------

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return const _NotFoundState();
          }

          final data = snapshot.data!.data()!;

          // ====================================================
          // DATOS DEL REPORTE
          // ====================================================

          final description =
              (data['description'] ?? 'Sin descripción')
                  .toString();

          final status =
              (data['status'] ?? 'Pendiente')
                  .toString();

          final adminDescription =
              (data['adminDescription'] ?? '')
                  .toString()
                  .trim();

          // ----------------------------------------------------
          // FOTO INICIAL
          // ----------------------------------------------------

          final initialImageUrl =
              _normalizeImageUrl(
            (data['imageUrl'] ?? '')
                .toString(),
          );

          // ----------------------------------------------------
          // FOTO FINAL
          // ----------------------------------------------------

          final finalImageUrl =
              _normalizeImageUrl(
            (data['finalImageUrl'] ?? '')
                .toString(),
          );

          // ====================================================
          // UBICACIÓN
          // ====================================================

          final locationData =
              data['location'];

          GeoPoint? geoPoint;

          if (locationData is GeoPoint) {
            geoPoint = locationData;
          }

          LatLng? reportLocation;

          if (geoPoint != null) {
            reportLocation = LatLng(
              geoPoint.latitude,
              geoPoint.longitude,
            );
          }

          // ====================================================
          // FECHA
          // ====================================================

          String fecha =
              'Fecha no disponible';

          final timestamp =
              data['timestamp'];

          if (timestamp is Timestamp) {
            final date =
                timestamp.toDate();

            fecha =
                '${date.day.toString().padLeft(2, '0')}/'
                '${date.month.toString().padLeft(2, '0')}/'
                '${date.year} • '
                '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}';
          }

          // ====================================================
          // INTERFAZ
          // ====================================================

          return Container(
            width: double.infinity,
            height: double.infinity,

            decoration:
                const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

                colors: [
                  Color(0xFFEFF9FA),
                  Color(0xFFF5F8F9),
                ],
              ),
            ),

            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // ENCABEZADO
                    // ==========================================

                    _HeaderCard(
                      description:
                          description,
                      createdAt:
                          timestamp is Timestamp
                              ? timestamp.toDate()
                              : null,
                      status:
                          status,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // DESCRIPCIÓN
                    // ==========================================

                    _SectionCard(
                      icon:
                          Icons.description_outlined,

                      title:
                          'Descripción del reporte',

                      child:
                          Text(
                        description,

                        style:
                            const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color:
                              Color(0xFF435254),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // EVIDENCIA INICIAL
                    // ==========================================

                    _SectionCard(
                      icon:
                          Icons.photo_camera_outlined,

                      title:
                          'Evidencia fotográfica inicial',

                      child:
                          _ReportImage(
                        imageUrl:
                            initialImageUrl,

                        emptyText:
                            'No hay fotografía inicial disponible',
                      ),
                    ),

                    // ==========================================
                    // FOTO FINAL
                    // ==========================================

                    if (finalImageUrl.isNotEmpty) ...[
                      const SizedBox(
                        height: 16,
                      ),

                      _SectionCard(
                        icon:
                            Icons.check_circle_outline,

                        title:
                            'Evidencia fotográfica final',

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Container(
                              width:
                                  double.infinity,

                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),

                              decoration:
                                  BoxDecoration(
                                color:
                                    kPrimaryLight,

                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),

                                border:
                                    Border.all(
                                  color:
                                      kPrimaryColor
                                          .withOpacity(
                                    0.20,
                                  ),
                                ),
                              ),

                              child:
                                  const Row(
                                children: [
                                  Icon(
                                    Icons
                                        .check_circle,
                                    color:
                                        kPrimaryDark,
                                    size: 20,
                                  ),

                                  SizedBox(
                                    width: 8,
                                  ),

                                  Expanded(
                                    child:
                                        Text(
                                      'Este reporte fue actualizado por el administrador.',
                                      style:
                                          TextStyle(
                                        color:
                                            kPrimaryDark,
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize:
                                            13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _ReportImage(
                              imageUrl:
                                  finalImageUrl,

                              emptyText:
                                  'No hay fotografía final disponible',
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ==========================================
                    // ESTADO
                    // ==========================================

                    const SizedBox(
                      height: 16,
                    ),

                    _SectionCard(
                      icon:
                          Icons.track_changes_outlined,

                      title:
                          'Estado del reporte',

                      child:
                          _StatusWidget(
                        status:
                            status,
                      ),
                    ),

                    // ==========================================
                    // COMENTARIO ADMINISTRADOR
                    // ==========================================

                    if (adminDescription
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 16,
                      ),

                      _SectionCard(
                        icon:
                            Icons
                                .admin_panel_settings_outlined,

                        title:
                            'Comentario del administrador',

                        child:
                            Container(
                          width:
                              double.infinity,

                          padding:
                              const EdgeInsets.all(
                            15,
                          ),

                          decoration:
                              BoxDecoration(
                            color:
                                kPrimaryLight,

                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),

                            border:
                                Border.all(
                              color:
                                  kPrimaryColor
                                      .withOpacity(
                                0.20,
                              ),
                            ),
                          ),

                          child:
                              Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(
                                  8,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color:
                                      kPrimaryColor
                                          .withOpacity(
                                    0.12,
                                  ),

                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                ),

                                child:
                                    const Icon(
                                  Icons
                                      .comment_outlined,

                                  color:
                                      kPrimaryDark,

                                  size:
                                      20,
                                ),
                              ),

                              const SizedBox(
                                width: 11,
                              ),

                              Expanded(
                                child:
                                    Text(
                                  adminDescription,

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        15,

                                    height:
                                        1.45,

                                    color:
                                        Color(
                                      0xFF435254,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ==========================================
                    // UBICACIÓN
                    // ==========================================

                    const SizedBox(
                      height: 16,
                    ),

                    _SectionCard(
                      icon:
                          Icons.location_on_outlined,

                      title:
                          'Ubicación del reporte',

                      child:
                          reportLocation != null
                              ? _MapWidget(
                                  location:
                                      reportLocation,
                                )
                              : Container(
                                  width:
                                      double.infinity,

                                  padding:
                                      const EdgeInsets.all(
                                    18,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.grey.shade100,

                                    borderRadius:
                                        BorderRadius.circular(
                                      14,
                                    ),
                                  ),

                                  child:
                                      const Row(
                                    children: [
                                      Icon(
                                        Icons
                                            .location_off_outlined,
                                        color:
                                            Colors.grey,
                                      ),

                                      SizedBox(
                                        width: 10,
                                      ),

                                      Text(
                                        'Ubicación no disponible',
                                        style:
                                            TextStyle(
                                          color:
                                              Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // NORMALIZAR URL
  // ============================================================

  static String _normalizeImageUrl(
    String url,
  ) {
    var result =
        url.trim();

    result =
        result.replaceAll(
      '&amp;',
      '&',
    );

    if (result.startsWith(
      'http://',
    )) {
      result =
          result.replaceFirst(
        'http://',
        'https://',
      );
    }

    return result;
  }
}

// ============================================================
// HEADER
// ============================================================

class _HeaderCard
    extends StatelessWidget {
  final String description;
  final DateTime? createdAt;
  final String status;

  const _HeaderCard({
    required this.description,
    required this.createdAt,
    required this.status,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    String fecha =
        'Fecha no disponible';

    if (createdAt != null) {
      fecha =
          '${createdAt!.day.toString().padLeft(2, '0')}/'
          '${createdAt!.month.toString().padLeft(2, '0')}/'
          '${createdAt!.year}';
    }

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.05,
            ),

            blurRadius:
                15,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width:
                55,

            height:
                55,

            decoration:
                BoxDecoration(
              color:
                  kPrimaryLight,

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child:
                const Icon(
              Icons.description_outlined,

              color:
                  kPrimaryDark,

              size:
                  29,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Reporte ciudadano',

                  style:
                      TextStyle(
                    fontSize:
                        13,

                    color:
                        Colors.grey,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  description,

                  maxLines:
                      2,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontSize:
                        20,

                    fontWeight:
                        FontWeight.w800,

                    color:
                        kTextColor,
                  ),
                ),

                const SizedBox(
                  height: 9,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons
                          .calendar_today_outlined,

                      size:
                          15,

                      color:
                          kPrimaryDark,
                    ),

                    const SizedBox(
                      width:
                          5,
                    ),

                    Text(
                      fecha,

                      style:
                          const TextStyle(
                        fontSize:
                            12,

                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TARJETA DE SECCIÓN
// ============================================================

class _SectionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.045,
            ),

            blurRadius:
                15,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width:
                    42,

                height:
                    42,

                decoration:
                    BoxDecoration(
                  color:
                      kPrimaryLight,

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  color:
                      kPrimaryDark,

                  size:
                      22,
                ),
              ),

              const SizedBox(
                width:
                    11,
              ),

              Expanded(
                child:
                    Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize:
                        17,

                    fontWeight:
                        FontWeight.w700,

                    color:
                        kTextColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                15,
          ),

          child,
        ],
      ),
    );
  }
}

// ============================================================
// IMAGEN
// ============================================================

class _ReportImage
    extends StatelessWidget {
  final String imageUrl;
  final String emptyText;

  const _ReportImage({
    required this.imageUrl,
    required this.emptyText,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (imageUrl.isEmpty) {
      return Container(
        width:
            double.infinity,

        height:
            240,

        decoration:
            BoxDecoration(
          color:
              Colors.grey.shade100,

          borderRadius:
              BorderRadius.circular(
            15,
          ),

          border:
              Border.all(
            color:
                Colors.grey.shade200,
          ),
        ),

        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons
                  .image_not_supported_outlined,

              size:
                  50,

              color:
                  Colors.grey,
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              emptyText,

              style:
                  const TextStyle(
                color:
                    Colors.grey,

                fontSize:
                    14,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        15,
      ),

      child:
          Container(
        width:
            double.infinity,

        height:
            360,

        color:
            const Color(
          0xFFF1F5F6,
        ),

        child:
            CachedNetworkImage(
          imageUrl:
              imageUrl,

          // ==================================================
          // IMPORTANTE:
          // contain = muestra TODA la fotografía
          // cover = recorta la fotografía
          // ==================================================

          fit:
              BoxFit.contain,

          alignment:
              Alignment.center,

          placeholder:
              (context, url) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color:
                    kPrimaryColor,
              ),
            );
          },

          errorWidget:
              (context, url, error) {
            return Center(
              child:
                  Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),

                child:
                    Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons
                          .broken_image_outlined,

                      size:
                          50,

                      color:
                          Colors.grey,
                    ),

                    const SizedBox(
                      height:
                          10,
                    ),

                    const Text(
                      'No se pudo cargar la fotografía',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            Colors.grey,

                        fontSize:
                            14,
                      ),
                    ),

                    const SizedBox(
                      height:
                          6,
                    ),

                    Text(
                      error.toString(),

                      maxLines:
                          2,

                      overflow:
                          TextOverflow.ellipsis,

                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color:
                            Colors.grey,

                        fontSize:
                            10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// ESTADO
// ============================================================

class _StatusWidget
    extends StatelessWidget {
  final String status;

  const _StatusWidget({
    required this.status,
  });

  Color _color() {
    final value =
        status.toLowerCase();

    if (value.contains('resuelto') ||
        value.contains('cerrado') ||
        value.contains('completado')) {
      return Colors.green;
    }

    if (value.contains('proceso') ||
        value.contains('asignado')) {
      return kPrimaryColor;
    }

    if (value.contains('mora')) {
      return Colors.red;
    }

    if (value.contains('pendiente')) {
      return Colors.orange;
    }

    return Colors.grey;
  }

  IconData _icon() {
    final value =
        status.toLowerCase();

    if (value.contains('resuelto') ||
        value.contains('cerrado') ||
        value.contains('completado')) {
      return Icons.check_circle_outline;
    }

    if (value.contains('proceso') ||
        value.contains('asignado')) {
      return Icons.autorenew;
    }

    if (value.contains('mora')) {
      return Icons.warning_amber_rounded;
    }

    if (value.contains('pendiente')) {
      return Icons.schedule;
    }

    return Icons.info_outline;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final color =
        _color();

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal:
            15,

        vertical:
            13,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.08,
        ),

        borderRadius:
            BorderRadius.circular(
          14,
        ),

        border:
            Border.all(
          color:
              color.withOpacity(
            0.20,
          ),
        ),
      ),

      child:
          Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(
              8,
            ),

            decoration:
                BoxDecoration(
              color:
                  color.withOpacity(
                0.12,
              ),

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              _icon(),

              color:
                  color,

              size:
                  22,
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          const Text(
            'Estado actual:',

            style:
                TextStyle(
              fontSize:
                  14,

              color:
                  Colors.black54,
            ),
          ),

          const SizedBox(
            width:
                7,
          ),

          Expanded(
            child:
                Text(
              status,

              style:
                  TextStyle(
                fontSize:
                    15,

                fontWeight:
                    FontWeight.w700,

                color:
                    color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAPA
// ============================================================

class _MapWidget
    extends StatelessWidget {
  final LatLng location;

  const _MapWidget({
    required this.location,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        15,
      ),

      child:
          SizedBox(
        height:
            230,

        width:
            double.infinity,

        child:
            GoogleMap(
          initialCameraPosition:
              CameraPosition(
            target:
                location,

            zoom:
                15,
          ),

          markers: {
            Marker(
              markerId:
                  const MarkerId(
                'report-location',
              ),

              position:
                  location,
            ),
          },

          zoomControlsEnabled:
              true,

          myLocationButtonEnabled:
              false,

          mapToolbarEnabled:
              true,
        ),
      ),
    );
  }
}

// ============================================================
// REPORTE NO ENCONTRADO
// ============================================================

class _NotFoundState
    extends StatelessWidget {
  const _NotFoundState();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            Icons
                .find_in_page_outlined,

            size:
                60,

            color:
                Colors.grey,
          ),

          SizedBox(
            height:
                15,
          ),

          Text(
            'Reporte no encontrado',

            style:
                TextStyle(
              fontSize:
                  18,

              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorState
    extends StatelessWidget {
  final String message;

  const _ErrorState({
    required this.message,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          25,
        ),

        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            const Icon(
              Icons
                  .cloud_off_outlined,

              size:
                  55,

              color:
                  kPrimaryColor,
            ),

            const SizedBox(
              height:
                  15,
            ),

            const Text(
              'No se pudo cargar el reporte',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize:
                    18,

                fontWeight:
                    FontWeight.w700,

                color:
                    kTextColor,
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            Text(
              message,

              textAlign:
                  TextAlign.center,

              style:
                  const TextStyle(
                fontSize:
                    13,

                color:
                    Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}