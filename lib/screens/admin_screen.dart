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
  final FirebaseService _firebaseService =
      FirebaseService();

  bool _orderByDate = true;

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEEEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: Color(0xFFD64545),
              size: 30,
            ),
          ),
          title: const Text(
            'Cerrar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF17343A),
            ),
          ),
          content: const Text(
            '¿Deseas cerrar la sesión administrativa?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(
                Icons.logout_rounded,
              ),
              label: const Text('Cerrar sesión'),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFD64545),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await _firebaseService.signOut();

    if (!mounted) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/login',
    );
  }

  // ============================================================
  // STREAM DE REPORTES
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _reportsStream() {
    final collection =
        FirebaseFirestore.instance
            .collection('reports');

    if (_orderByDate) {
      return collection
          .orderBy(
            'timestamp',
            descending: true,
          )
          .snapshots();
    }

    return collection.snapshots();
  }

  // ============================================================
  // ACTUALIZAR
  // ============================================================

  Future<void> _refresh() async {
    await Future<void>.delayed(
      const Duration(
        milliseconds: 300,
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // COLOR DEL ESTADO
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    final s =
        status.toLowerCase().trim();

    if (s.contains('mora')) {
      return const Color(0xFFD9822B);
    }

    if (s.contains('pend')) {
      return const Color(0xFF9A7B00);
    }

    if (s.contains('resuelto') ||
        s.contains('cerr') ||
        s.contains('complet')) {
      return const Color(0xFF168C95);
    }

    if (s.contains('proceso') ||
        s.contains('progres') ||
        s.contains('asign')) {
      return const Color(0xFF3976B8);
    }

    return const Color(0xFF777777);
  }

  // ============================================================
  // FORMATO DE FECHA
  // ============================================================

  String _formatDate(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return 'Sin fecha';
    }

    final date =
        timestamp.toDate();

    return DateFormat(
      'dd/MM/yyyy • HH:mm',
    ).format(date);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F8F8),

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            Colors.white,
        surfaceTintColor:
            Colors.white,

        leading: Container(
          margin:
              const EdgeInsets.only(
            left: 12,
            top: 8,
            bottom: 8,
          ),
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFF27B3BB),
                Color(0xFF168C95),
              ],
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),

        title: const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Panel de Administración',
              style: TextStyle(
                color:
                    Color(0xFF17343A),
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            Text(
              'Gestión de reportes',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
            ),
          ],
        ),

        actions: [
          // ------------------------------------------------------
          // ORDENAR
          // ------------------------------------------------------

          IconButton(
            tooltip:
                _orderByDate
                    ? 'Orden actual: más recientes'
                    : 'Orden actual: sin ordenar',
            icon: Icon(
              _orderByDate
                  ? Icons.schedule_rounded
                  : Icons.sort_rounded,
              color:
                  const Color(0xFF168C95),
            ),
            onPressed: () {
              setState(() {
                _orderByDate =
                    !_orderByDate;
              });
            },
          ),

          // ------------------------------------------------------
          // CERRAR SESIÓN
          // ------------------------------------------------------

          IconButton(
            tooltip:
                'Cerrar sesión',
            icon: const Icon(
              Icons.logout_rounded,
              color:
                  Color(0xFFD64545),
            ),
            onPressed: _signOut,
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      body: RefreshIndicator(
        color:
            const Color(0xFF168C95),
        onRefresh: _refresh,

        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream:
              _reportsStream(),

          builder: (
            context,
            snapshot,
          ) {
            // ====================================================
            // CARGANDO
            // ====================================================

            if (snapshot
                    .connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Color(0xFF168C95),
                ),
              );
            }

            // ====================================================
            // ERROR
            // ====================================================

            if (snapshot.hasError) {
              return _ErrorState(
                message:
                    'No se pudieron cargar los reportes.\n\n${snapshot.error}',
                onRetry: _refresh,
              );
            }

            // ====================================================
            // DOCUMENTOS
            // ====================================================

            final docs =
                snapshot.data?.docs ??
                    [];

            // ====================================================
            // SIN REPORTES
            // ====================================================

            if (docs.isEmpty) {
              return const _EmptyState();
            }

            // ====================================================
            // LISTA
            // ====================================================

            return LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final isWide =
                    constraints
                            .maxWidth >
                        900;

                final horizontalPadding =
                    isWide ? 40.0 : 16.0;

                return ListView
                    .separated(
                  physics:
                      const AlwaysScrollableScrollPhysics(),

                  padding:
                      EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    30,
                  ),

                  itemCount:
                      docs.length,

                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 14,
                  ),

                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final doc =
                        docs[index];

                    final data =
                        doc.data();

                    final description =
                        (data[
                                      'description'] ??
                                  'Sin descripción')
                            .toString();

                    final userId =
                        (data[
                                      'userId'] ??
                                  '—')
                            .toString();

                    final imageUrl =
                        (data[
                                      'imageUrl'] ??
                                  '')
                            .toString();

                    final timestamp =
                        data[
                            'timestamp'];

                    final ts =
                        timestamp
                                is Timestamp
                            ? timestamp
                            : null;

                    final status =
                        (data[
                                      'status'] ??
                                  'Pendiente')
                            .toString();

                    final adminDescription =
                        (data[
                                      'adminDescription'] ??
                                  '')
                            .toString();

                    return _ReportAdminCard(
                      reportId:
                          doc.id,
                      description:
                          description,
                      userId:
                          userId,
                      imageUrl:
                          imageUrl,
                      dateText:
                          _formatDate(
                        ts,
                      ),
                      status:
                          status,
                      statusColor:
                          _statusColor(
                        status,
                      ),
                      adminDescription:
                          adminDescription,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    ReportDetailsScreen(
                              reportId:
                                  doc.id,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =================================================================
// TARJETA DEL REPORTE
// =================================================================

class _ReportAdminCard
    extends StatelessWidget {
  final String reportId;
  final String description;
  final String userId;
  final String imageUrl;
  final String dateText;
  final String status;
  final Color statusColor;
  final String adminDescription;
  final VoidCallback onTap;

  const _ReportAdminCard({
    required this.reportId,
    required this.description,
    required this.userId,
    required this.imageUrl,
    required this.dateText,
    required this.status,
    required this.statusColor,
    required this.adminDescription,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        child: Container(
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color:
                  Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(
                  0.035,
                ),
                blurRadius: 16,
                offset:
                    const Offset(
                  0,
                  5,
                ),
              ),
            ],
          ),

          child: Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),

            child: LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final isSmall =
                    constraints
                            .maxWidth <
                        560;

                if (isSmall) {
                  return _SmallCardContent(
                    imageUrl:
                        imageUrl,
                    description:
                        description,
                    userId:
                        userId,
                    dateText:
                        dateText,
                    status:
                        status,
                    statusColor:
                        statusColor,
                    adminDescription:
                        adminDescription,
                    reportId:
                        reportId,
                  );
                }

                return _LargeCardContent(
                  imageUrl:
                      imageUrl,
                  description:
                      description,
                  userId:
                      userId,
                  dateText:
                      dateText,
                  status:
                      status,
                  statusColor:
                      statusColor,
                  adminDescription:
                      adminDescription,
                  reportId:
                      reportId,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =================================================================
// TARJETA GRANDE
// =================================================================

class _LargeCardContent
    extends StatelessWidget {
  final String imageUrl;
  final String description;
  final String userId;
  final String dateText;
  final String status;
  final Color statusColor;
  final String adminDescription;
  final String reportId;

  const _LargeCardContent({
    required this.imageUrl,
    required this.description,
    required this.userId,
    required this.dateText,
    required this.status,
    required this.statusColor,
    required this.adminDescription,
    required this.reportId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        // ========================================================
        // IMAGEN
        // ========================================================

        _ReportThumbnail(
          imageUrl:
              imageUrl,
          size: 105,
        ),

        const SizedBox(
          width: 16,
        ),

        // ========================================================
        // CONTENIDO
        // ========================================================

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF17343A,
                        ),
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  _StatusBadge(
                    status:
                        status,
                    color:
                        statusColor,
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  _MetadataItem(
                    icon: Icons
                        .calendar_today_outlined,
                    text:
                        dateText,
                  ),

                  _MetadataItem(
                    icon: Icons
                        .person_outline_rounded,
                    text:
                        userId,
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              if (adminDescription
                  .isNotEmpty)
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .all(
                    11,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF1F8F8,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Icon(
                        Icons
                            .comment_outlined,
                        size: 17,
                        color:
                            Color(
                          0xFF168C95,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          adminDescription,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 12,
                            color:
                                Color(
                              0xFF35545A,
                            ),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(
                height: 12,
              ),

              Row(
                children: [
                  _ReportIdBadge(
                    reportId:
                        reportId,
                  ),

                  const Spacer(),

                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    color:
                        Color(
                      0xFF168C95,
                    ),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =================================================================
// TARJETA PEQUEÑA
// =================================================================

class _SmallCardContent
    extends StatelessWidget {
  final String imageUrl;
  final String description;
  final String userId;
  final String dateText;
  final String status;
  final Color statusColor;
  final String adminDescription;
  final String reportId;

  const _SmallCardContent({
    required this.imageUrl,
    required this.description,
    required this.userId,
    required this.dateText,
    required this.status,
    required this.statusColor,
    required this.adminDescription,
    required this.reportId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,

      children: [
        Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [
            _ReportThumbnail(
              imageUrl:
                  imageUrl,
              size: 78,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    description,
                    maxLines: 3,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF17343A,
                      ),
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _StatusBadge(
                    status:
                        status,
                    color:
                        statusColor,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 14,
        ),

        Wrap(
          spacing: 12,
          runSpacing: 7,
          children: [
            _MetadataItem(
              icon: Icons
                  .calendar_today_outlined,
              text:
                  dateText,
            ),

            _MetadataItem(
              icon: Icons
                  .person_outline_rounded,
              text:
                  userId,
            ),
          ],
        ),

        if (adminDescription
            .isNotEmpty) ...[
          const SizedBox(
            height: 12,
          ),

          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              11,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF1F8F8,
              ),
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                const Icon(
                  Icons
                      .comment_outlined,
                  size: 17,
                  color:
                      Color(
                    0xFF168C95,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    adminDescription,
                    maxLines: 3,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          Color(
                        0xFF35545A,
                      ),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(
          height: 13,
        ),

        Row(
          children: [
            _ReportIdBadge(
              reportId:
                  reportId,
            ),

            const Spacer(),

            const Icon(
              Icons
                  .arrow_forward_rounded,
              color:
                  Color(0xFF168C95),
              size: 20,
            ),
          ],
        ),
      ],
    );
  }
}

// =================================================================
// MINIATURA
// =================================================================

class _ReportThumbnail
    extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _ReportThumbnail({
    required this.imageUrl,
    this.size = 90,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (imageUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(
          color:
              const Color(0xFFF0F3F3),
          borderRadius:
              BorderRadius.circular(
            15,
          ),
        ),
        child: Icon(
          Icons
              .image_not_supported_outlined,
          color:
              Colors.grey.shade400,
          size: 30,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(
        15,
      ),

      child:
          CachedNetworkImage(
        imageUrl:
            imageUrl,

        width:
            size,

        height:
            size,

        fit:
            BoxFit.cover,

        placeholder:
            (
          context,
          url,
        ) {
          return Container(
            width: size,
            height: size,
            color:
                const Color(
              0xFFF0F3F3,
            ),
            alignment:
                Alignment.center,
            child:
                const SizedBox(
              width: 20,
              height: 20,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color:
                    Color(
                  0xFF168C95,
                ),
              ),
            ),
          );
        },

        errorWidget:
            (
          context,
          url,
          error,
        ) {
          return Container(
            width: size,
            height: size,
            color:
                const Color(
              0xFFF0F3F3,
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .broken_image_outlined,
              color:
                  Colors.grey,
              size: 30,
            ),
          );
        },
      ),
    );
  }
}

// =================================================================
// ESTADO
// =================================================================

class _StatusBadge
    extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({
    required this.status,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 11,
        vertical: 7,
      ),

      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.11,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              color.withOpacity(
            0.18,
          ),
        ),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(
              color: color,
              shape:
                  BoxShape.circle,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Text(
            status,
            style:
                TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// METADATO
// =================================================================

class _MetadataItem
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetadataItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        Icon(
          icon,
          size: 15,
          color:
              Colors.grey.shade600,
        ),

        const SizedBox(
          width: 6,
        ),

        ConstrainedBox(
          constraints:
              const BoxConstraints(
            maxWidth: 260,
          ),

          child: Text(
            text,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// ID DEL REPORTE
// =================================================================

class _ReportIdBadge
    extends StatelessWidget {
  final String reportId;

  const _ReportIdBadge({
    required this.reportId,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth: 230,
      ),

      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF4F6F6),
        borderRadius:
            BorderRadius.circular(
          9,
        ),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons.tag_rounded,
            size: 15,
            color:
                Color(0xFF168C95),
          ),

          const SizedBox(
            width: 5,
          ),

          Flexible(
            child: Text(
              reportId,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    Color(0xFF60777C),
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// ESTADO VACÍO
// =================================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.65,

          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets
                      .all(
                30,
              ),

              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(
                        0xFFE8F7F8,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons
                          .description_outlined,
                      color:
                          Color(
                        0xFF168C95,
                      ),
                      size: 45,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  const Text(
                    'No hay reportes',
                    style:
                        TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xFF17343A,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Cuando los ciudadanos registren problemas de infraestructura, aparecerán aquí.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey
                              .shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// ERROR
// =================================================================

class _ErrorState
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),

      children: [
        SizedBox(
          height:
              MediaQuery.of(context)
                      .size
                      .height *
                  0.65,

          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets
                      .all(
                30,
              ),

              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration:
                        const BoxDecoration(
                      color:
                          Color(
                        0xFFFFEEEE,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons
                          .error_outline_rounded,
                      color:
                          Color(
                        0xFFD64545,
                      ),
                      size: 40,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'No se pudieron cargar los reportes',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize: 19,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xFF17343A,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Text(
                    message,
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey
                              .shade600,
                      height: 1.4,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  FilledButton.icon(
                    onPressed:
                        onRetry,
                    icon:
                        const Icon(
                      Icons
                          .refresh_rounded,
                    ),
                    label:
                        const Text(
                      'Intentar nuevamente',
                    ),
                    style:
                        FilledButton
                            .styleFrom(
                      backgroundColor:
                          const Color(
                        0xFF168C95,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}