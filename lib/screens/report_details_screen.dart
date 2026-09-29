import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailsScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState
    extends State<ReportDetailsScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  // ============================================================
  // ESTADO
  // ============================================================

  bool _isSaving = false;
  double _uploadProgress = 0.0;

  String _status = 'En progreso';

  final TextEditingController _adminDescController =
      TextEditingController();

  Uint8List? _finalImageBytes;
  String? _finalImageUrlPreview;

  LatLng? _location;

  // ============================================================
  // CARGAR REPORTE
  // ============================================================

  Future<DocumentSnapshot<Map<String, dynamic>>>
      _loadReportDetails() {
    return _firestore
        .collection('reports')
        .doc(widget.reportId)
        .get();
  }

  // ============================================================
  // SELECCIONAR IMAGEN FINAL
  // ============================================================

  Future<void> _pickFinalImage() async {
    try {
      if (kIsWeb) {
        final Uint8List? picked =
            await ImagePickerWeb.getImageAsBytes();

        if (picked != null) {
          setState(() {
            _finalImageBytes = picked;
          });
        }
      } else {
        final ImagePicker picker =
            ImagePicker();

        final XFile? x =
            await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          imageQuality: 85,
        );

        if (x != null) {
          final bytes =
              await x.readAsBytes();

          setState(() {
            _finalImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      _snack(
        'No se pudo seleccionar la imagen.',
        isError: true,
      );
    }
  }

  void _removeFinalImage() {
    setState(() {
      _finalImageBytes = null;
    });
  }

  // ============================================================
  // SUBIR IMAGEN FINAL
  // ============================================================

  Future<String?> _uploadFinalImageIfNeeded() async {
    if (_finalImageBytes == null) {
      return _finalImageUrlPreview;
    }

    try {
      setState(() {
        _uploadProgress = 0.0;
      });

      final fileName =
          'final_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = _storage.ref(
        'final_report_images/$fileName',
      );

      final metadata =
          SettableMetadata(
        contentType: 'image/jpeg',
      );

      final uploadTask =
          ref.putData(
        _finalImageBytes!,
        metadata,
      );

      uploadTask.snapshotEvents.listen(
        (e) {
          if (e.totalBytes > 0 &&
              mounted) {
            setState(() {
              _uploadProgress =
                  e.bytesTransferred /
                      e.totalBytes;
            });
          }
        },
      );

      final snap =
          await uploadTask;

      return await snap.ref
          .getDownloadURL();
    } catch (e) {
      _snack(
        'Error al subir la imagen final.',
        isError: true,
      );

      return null;
    }
  }

  // ============================================================
  // GUARDAR CAMBIOS
  // ============================================================

  Future<void> _updateReport() async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration:
                const BoxDecoration(
              color: Color(0xFFE7F6F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.save_rounded,
              color: Color(0xFF168C95),
              size: 30,
            ),
          ),
          title: const Text(
            'Actualizar reporte',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '¿Deseas guardar los cambios realizados en este reporte?',
            textAlign: TextAlign.center,
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              icon: const Icon(
                Icons.check_rounded,
              ),
              label:
                  const Text('Guardar'),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF168C95,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      final newUrl =
          await _uploadFinalImageIfNeeded();

      final data =
          <String, dynamic>{
        'status': _status,

        'adminDescription':
            _adminDescController
                    .text
                    .trim()
                    .isEmpty
                ? null
                : _adminDescController
                    .text
                    .trim(),

        'finalImageUrl':
            newUrl,

        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      data.removeWhere(
        (key, value) =>
            value == null,
      );

      await _firestore
          .collection('reports')
          .doc(widget.reportId)
          .update(data);

      if (!mounted) {
        return;
      }

      await _showSuccessDialog();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _snack(
          'Error al actualizar el reporte.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // MENSAJE
  // ============================================================

  void _snack(
    String msg, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFD64545)
            : const Color(0xFF168C95),
        behavior:
            SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGO DE ÉXITO
  // ============================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),
          icon: Container(
            width: 72,
            height: 72,
            decoration:
                const BoxDecoration(
              color: Color(0xFFE5F7F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF168C95),
              size: 42,
            ),
          ),
          title: const Text(
            '¡Reporte actualizado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF17343A),
            ),
          ),
          content: const Text(
            'Los cambios del reporte se guardaron correctamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.4,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 150,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF168C95,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 13,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                child:
                    const Text('Aceptar'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _adminDescController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        DocumentSnapshot<
            Map<String, dynamic>>>(
      future: _loadReportDetails(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Scaffold(
            backgroundColor:
                const Color(0xFFF4F8F8),
            appBar:
                _buildAppBar(),
            body: const Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFF168C95),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor:
                const Color(0xFFF4F8F8),
            appBar:
                _buildAppBar(),
            body: _ErrorState(
              message:
                  'No se pudo cargar la información del reporte.',
              onRetry: () {
                setState(() {});
              },
            ),
          );
        }

        if (!snapshot.hasData ||
            !(snapshot.data?.exists ??
                false)) {
          return Scaffold(
            backgroundColor:
                const Color(0xFFF4F8F8),
            appBar:
                _buildAppBar(),
            body: const _ErrorState(
              message:
                  'Reporte no encontrado.',
            ),
          );
        }

        final doc =
            snapshot.data!;

        final data =
            doc.data()!;

        // ========================================================
        // DATOS
        // ========================================================

        _status =
            (data['status']
                    as String?) ??
                _status;

        _adminDescController.text =
            (data['adminDescription']
                    as String?) ??
                _adminDescController.text;

        _finalImageUrlPreview =
            data['finalImageUrl']
                as String?;

        final initialImageUrl =
            data['imageUrl']
                as String?;

        final geo =
            data['location']
                as GeoPoint?;

        _location = geo != null
            ? LatLng(
                geo.latitude,
                geo.longitude,
              )
            : null;

        final createdAt =
            (data['timestamp']
                    as Timestamp?)
                ?.toDate();

        // ========================================================
        // INTERFAZ
        // ========================================================

        return Scaffold(
          backgroundColor:
              const Color(0xFFF4F8F8),

          appBar:
              _buildAppBar(),

          body: SafeArea(
            child:
                LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                return SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(
                    horizontal:
                        constraints.maxWidth >
                                900
                            ? 40
                            : 16,
                    vertical: 24,
                  ),
                  child:
                      Center(
                    child:
                        ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 1100,
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .stretch,
                        children: [
                          // ======================================
                          // CABECERA
                          // ======================================

                          _HeaderCard(
                            description:
                                data['description'] ??
                                    'Sin descripción',
                            userId:
                                data['userId'] ??
                                    '—',
                            createdAt:
                                createdAt,
                            status:
                                _status,
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          // ======================================
                          // PROGRESO
                          // ======================================

                          if (_isSaving)
                            _SavingProgress(
                              progress:
                                  _uploadProgress,
                            ),

                          if (_isSaving)
                            const SizedBox(
                              height: 16,
                            ),

                          // ======================================
                          // IMÁGENES
                          // ======================================

                          _SectionContainer(
                            icon: Icons
                                .photo_library_outlined,
                            title:
                                'Evidencia fotográfica',
                            child:
                                _ImagesSection(
                              initialImageUrl:
                                  initialImageUrl,
                              finalImageUrl:
                                  _finalImageUrlPreview,
                              finalBytes:
                                  _finalImageBytes,
                              onPick:
                                  _pickFinalImage,
                              onRemove:
                                  _removeFinalImage,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          // ======================================
                          // UBICACIÓN
                          // ======================================

                          _SectionContainer(
                            icon: Icons
                                .location_on_outlined,
                            title:
                                'Ubicación del reporte',
                            child:
                                _LocationSection(
                              location:
                                  _location,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          // ======================================
                          // ESTADO
                          // ======================================

                          _SectionContainer(
                            icon: Icons
                                .track_changes_rounded,
                            title:
                                'Estado y seguimiento',
                            child:
                                _StatusAndNotes(
                              status:
                                  _status,
                              onStatusChanged:
                                  (s) {
                                setState(() {
                                  _status =
                                      s;
                                });
                              },
                              adminDescController:
                                  _adminDescController,
                            ),
                          ),

                          const SizedBox(
                            height: 22,
                          ),

                          // ======================================
                          // BOTONES
                          // ======================================

                          _ActionButtons(
                            isSaving:
                                _isSaving,
                            onSave:
                                _updateReport,
                            onClear: () {
                              setState(() {
                                _finalImageBytes =
                                    null;

                                _uploadProgress =
                                    0.0;
                              });

                              _adminDescController
                                  .clear();
                            },
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
          ),
        );
      },
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,

      leading:
          IconButton(
        tooltip: 'Volver',
        icon: const Icon(
          Icons.arrow_back_rounded,
          color:
              Color(0xFF17343A),
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),

      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
                11,
              ),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          const Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                'Detalles del reporte',
                style: TextStyle(
                  color:
                      Color(0xFF17343A),
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                'Gestión administrativa',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),

      actions: [
        IconButton(
          tooltip: 'Ayuda',
          onPressed:
              _showHelpDialog,
          icon: const Icon(
            Icons.help_outline_rounded,
            color:
                Color(0xFF168C95),
          ),
        ),

        const SizedBox(
          width: 8,
        ),
      ],
    );
  }

  // ============================================================
  // AYUDA
  // ============================================================

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),

          icon: const Icon(
            Icons.info_outline_rounded,
            color:
                Color(0xFF168C95),
            size: 38,
          ),

          title: const Text(
            'Ayuda',
            textAlign: TextAlign.center,
          ),

          content:
              const Text(
            'En esta pantalla puedes revisar la información del reporte, consultar su ubicación, actualizar el estado, añadir una descripción de seguimiento y adjuntar una imagen final.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              height: 1.45,
            ),
          ),

          actionsAlignment:
              MainAxisAlignment.center,

          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF168C95,
                ),
              ),
              child:
                  const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// HEADER DEL REPORTE
// =================================================================

class _HeaderCard
    extends StatelessWidget {
  final String description;
  final String userId;
  final DateTime? createdAt;
  final String status;

  const _HeaderCard({
    required this.description,
    required this.userId,
    required this.createdAt,
    required this.status,
  });

  String _formatDate() {
    if (createdAt == null) {
      return '—';
    }

    return '${createdAt!.day.toString().padLeft(2, '0')}/'
        '${createdAt!.month.toString().padLeft(2, '0')}/'
        '${createdAt!.year}';
  }

  Color _statusColor() {
    switch (status) {
      case 'Resuelto':
        return const Color(0xFF168C95);

      case 'En progreso':
        return const Color(0xFF3976B8);

      case 'En mora':
        return const Color(0xFFD9822B);

      default:
        return const Color(0xFF777777);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final color =
        _statusColor();

    return Container(
      padding:
          const EdgeInsets.all(22),

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
                .withOpacity(0.035),
            blurRadius: 16,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

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
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color: const Color(
                    0xFFE8F7F8,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color:
                      Color(0xFF168C95),
                  size: 25,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'Reporte ciudadano',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      description,
                      style:
                          const TextStyle(
                        color: Color(
                          0xFF17343A,
                        ),
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration:
                    BoxDecoration(
                  color: color
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  status,
                  style:
                      TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon:
                    Icons.person_outline,
                label:
                    'Usuario: $userId',
              ),

              _InfoPill(
                icon:
                    Icons.calendar_today_outlined,
                label:
                    'Creado: ${_formatDate()}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =================================================================
// CONTENEDOR DE SECCIÓN
// =================================================================

class _SectionContainer
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionContainer({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
                .withOpacity(0.03),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,

          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    color: const Color(
                      0xFFE8F7F8,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      11,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        const Color(
                      0xFF168C95,
                    ),
                    size: 20,
                  ),
                ),

                const SizedBox(
                  width: 11,
                ),

                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Color(
                      0xFF17343A,
                    ),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            child,
          ],
        ),
      ),
    );
  }
}

// =================================================================
// IMÁGENES
// =================================================================

class _ImagesSection
    extends StatelessWidget {
  final String? initialImageUrl;
  final String? finalImageUrl;
  final Uint8List? finalBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagesSection({
    required this.initialImageUrl,
    required this.finalImageUrl,
    required this.finalBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isWide =
            constraints.maxWidth >
                700;

        if (isWide) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Expanded(
                child:
                    _ImageTile(
                  title:
                      'Imagen inicial',
                  url:
                      initialImageUrl,
                  emptyText:
                      'Sin imagen inicial',
                ),
              ),

              const SizedBox(
                width: 18,
              ),

              Expanded(
                child:
                    _FinalImageTile(
                  title:
                      'Imagen final',
                  url:
                      finalImageUrl,
                  bytes:
                      finalBytes,
                  onPick:
                      onPick,
                  onRemove:
                      onRemove,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _ImageTile(
              title:
                  'Imagen inicial',
              url:
                  initialImageUrl,
              emptyText:
                  'Sin imagen inicial',
            ),

            const SizedBox(
              height: 18,
            ),

            _FinalImageTile(
              title:
                  'Imagen final',
              url:
                  finalImageUrl,
              bytes:
                  finalBytes,
              onPick:
                  onPick,
              onRemove:
                  onRemove,
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// IMAGEN INICIAL
// =================================================================

class _ImageTile
    extends StatelessWidget {
  final String title;
  final String? url;
  final String emptyText;

  const _ImageTile({
    required this.title,
    this.url,
    required this.emptyText,
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
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xFF17343A),
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        AspectRatio(
          aspectRatio: 16 / 9,

          child: Container(
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFF4F6F6,
              ),
              borderRadius:
                  BorderRadius.circular(
                15,
              ),
              border: Border.all(
                color:
                    Colors.grey.shade200,
              ),
            ),

            clipBehavior:
                Clip.antiAlias,

            child: url != null &&
                    url!.isNotEmpty
                ? InkWell(
                    onTap: () {
                      _showImage(
                        context,
                        url!,
                      );
                    },
                    child:
                        Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const _ImagePlaceholder(
                          text:
                              'No se pudo cargar la imagen',
                        );
                      },
                    ),
                  )
                : _ImagePlaceholder(
                    text: emptyText,
                  ),
          ),
        ),
      ],
    );
  }

  void _showImage(
    BuildContext context,
    String url,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor:
              Colors.black,
          insetPadding:
              const EdgeInsets.all(
            16,
          ),
          child: InteractiveViewer(
            child:
                Image.network(
              url,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

// =================================================================
// IMAGEN FINAL
// =================================================================

class _FinalImageTile
    extends StatelessWidget {
  final String title;
  final String? url;
  final Uint8List? bytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _FinalImageTile({
    required this.title,
    required this.url,
    required this.bytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasLocal =
        bytes != null;

    final hasRemote =
        url != null &&
        url!.isNotEmpty &&
        !hasLocal;

    Widget content;

    if (hasLocal) {
      content =
          Image.memory(
        bytes!,
        fit: BoxFit.cover,
      );
    } else if (hasRemote) {
      content =
          Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder:
            (
          context,
          error,
          stackTrace,
        ) {
          return const _ImagePlaceholder(
            text:
                'No se pudo cargar la imagen',
          );
        },
      );
    } else {
      content =
          const _ImagePlaceholder(
        text: 'Sin imagen final',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Imagen final',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(0xFF17343A),
                ),
              ),
            ),

            if (hasLocal)
              IconButton(
                tooltip:
                    'Quitar imagen',
                onPressed:
                    onRemove,
                icon:
                    const Icon(
                  Icons.delete_outline_rounded,
                  color:
                      Color(0xFFD64545),
                  size: 21,
                ),
              ),
          ],
        ),

        const SizedBox(
          height: 2,
        ),

        AspectRatio(
          aspectRatio: 16 / 9,

          child: Stack(
            children: [
              Positioned.fill(
                child:
                    Container(
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF4F6F6,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.grey.shade200,
                    ),
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child:
                      content,
                ),
              ),

              Positioned(
                right: 10,
                top: 10,
                child:
                    Material(
                  color: Colors.black
                      .withOpacity(
                    0.60,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                  child:
                      InkWell(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                    onTap: onPick,
                    child:
                        const Padding(
                      padding:
                          EdgeInsets.all(
                        11,
                      ),
                      child:
                          Icon(
                        Icons
                            .upload_rounded,
                        color:
                            Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          hasLocal
              ? 'Nueva imagen seleccionada'
              : hasRemote
                  ? 'Imagen final guardada'
                  : 'Puedes adjuntar una imagen como evidencia de la solución',

          style: TextStyle(
            color:
                Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// =================================================================
// PLACEHOLDER DE IMAGEN
// =================================================================

class _ImagePlaceholder
    extends StatelessWidget {
  final String text;

  const _ImagePlaceholder({
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              Icons
                  .image_outlined,
              color:
                  Colors.grey.shade400,
              size: 42,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              text,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// UBICACIÓN
// =================================================================

class _LocationSection
    extends StatelessWidget {
  final LatLng? location;

  const _LocationSection({
    required this.location,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (location == null) {
      return Container(
        height: 180,
        alignment:
            Alignment.center,
        decoration:
            BoxDecoration(
          color:
              const Color(0xFFF5F7F7),
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
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(
              Icons
                  .location_off_outlined,
              color:
                  Colors.grey.shade400,
              size: 40,
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Sin coordenadas disponibles',
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,

      children: [
        Container(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFF1F8F8,
            ),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .location_on_outlined,
                color:
                    Color(0xFF168C95),
                size: 18,
              ),
              const SizedBox(
                width: 8,
              ),
              Expanded(
                child: Text(
                  'Lat: ${location!.latitude.toStringAsFixed(6)}   •   Lng: ${location!.longitude.toStringAsFixed(6)}',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Color(
                      0xFF35545A,
                    ),
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          height: 300,

          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
              15,
            ),

            child:
                GoogleMap(
              initialCameraPosition:
                  CameraPosition(
                target:
                    location!,
                zoom: 14,
              ),

              markers: {
                Marker(
                  markerId:
                      const MarkerId(
                    'reportLocation',
                  ),
                  position:
                      location!,
                ),
              },

              zoomControlsEnabled:
                  true,

              myLocationButtonEnabled:
                  false,

              myLocationEnabled:
                  false,

              mapToolbarEnabled:
                  false,
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// ESTADO Y SEGUIMIENTO
// =================================================================

class _StatusAndNotes
    extends StatelessWidget {
  final String status;
  final ValueChanged<String>
      onStatusChanged;
  final TextEditingController
      adminDescController;

  const _StatusAndNotes({
    required this.status,
    required this.onStatusChanged,
    required this.adminDescController,
  });

  static const List<String>
      _statuses = [
    'Pendiente',
    'En progreso',
    'En mora',
    'Resuelto',
  ];

  Color _chipColor(
    String status,
  ) {
    switch (status) {
      case 'Resuelto':
        return const Color(
          0xFF168C95,
        );

      case 'En mora':
        return const Color(
          0xFFD9822B,
        );

      case 'En progreso':
        return const Color(
          0xFF3976B8,
        );

      default:
        return const Color(
          0xFF777777,
        );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .start,

      children: [
        const Text(
          'Selecciona el estado actual del reporte',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        Wrap(
          spacing: 9,
          runSpacing: 9,

          children:
              _statuses.map(
            (s) {
              final selected =
                  s == status;

              final color =
                  _chipColor(s);

              return ChoiceChip(
                label: Text(s),
                selected:
                    selected,

                selectedColor:
                    color,

                backgroundColor:
                    const Color(
                  0xFFF4F6F6,
                ),

                side: BorderSide(
                  color: selected
                      ? color
                      : Colors.grey
                          .shade200,
                ),

                labelStyle:
                    TextStyle(
                  color: selected
                      ? Colors.white
                      : const Color(
                          0xFF455A60,
                        ),
                  fontWeight:
                      selected
                          ? FontWeight.bold
                          : FontWeight.w500,
                  fontSize: 12,
                ),

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),

                onSelected:
                    (_) {
                  onStatusChanged(
                    s,
                  );
                },
              );
            },
          ).toList(),
        ),

        const SizedBox(
          height: 20,
        ),

        const Text(
          'Descripción de seguimiento',
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xFF17343A),
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        TextFormField(
          controller:
              adminDescController,

          maxLines: 5,

          textCapitalization:
              TextCapitalization
                  .sentences,

          decoration:
              InputDecoration(
            hintText:
                'Escribe información relacionada con la atención del reporte...',

            hintStyle:
                TextStyle(
              color:
                  Colors.grey.shade400,
              fontSize: 13,
            ),

            filled: true,

            fillColor:
                const Color(
              0xFFF8FAFA,
            ),

            contentPadding:
                const EdgeInsets
                    .all(
              15,
            ),

            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade200,
              ),
            ),

            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  BorderSide(
                color:
                    Colors.grey.shade200,
              ),
            ),

            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  const BorderSide(
                color:
                    Color(0xFF168C95),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =================================================================
// BOTONES
// =================================================================

class _ActionButtons
    extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onClear;

  const _ActionButtons({
    required this.isSaving,
    required this.onSave,
    required this.onClear,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isSmall =
            constraints.maxWidth <
                560;

        if (isSmall) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              FilledButton.icon(
                onPressed:
                    isSaving
                        ? null
                        : onSave,
                icon: const Icon(
                  Icons.save_rounded,
                ),
                label:
                    const Text(
                  'Guardar cambios',
                ),
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF168C95,
                  ),
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 15,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              OutlinedButton.icon(
                onPressed:
                    isSaving
                        ? null
                        : onClear,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text(
                  'Limpiar cambios',
                ),
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      const Color(
                    0xFF455A60,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 15,
                  ),
                  side:
                      BorderSide(
                    color:
                        Colors.grey
                            .shade300,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child:
                  FilledButton.icon(
                onPressed:
                    isSaving
                        ? null
                        : onSave,
                icon: const Icon(
                  Icons.save_rounded,
                ),
                label:
                    const Text(
                  'Guardar cambios',
                ),
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF168C95,
                  ),
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 15,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            OutlinedButton.icon(
              onPressed:
                  isSaving
                      ? null
                      : onClear,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text(
                'Limpiar',
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF455A60,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 22,
                  vertical: 15,
                ),
                side:
                    BorderSide(
                  color:
                      Colors.grey
                          .shade300,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =================================================================
// PROGRESO DE GUARDADO
// =================================================================

class _SavingProgress
    extends StatelessWidget {
  final double progress;

  const _SavingProgress({
    required this.progress,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasProgress =
        progress > 0;

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Color(0xFF168C95),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              const Expanded(
                child: Text(
                  'Guardando cambios...',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF17343A),
                  ),
                ),
              ),

              if (hasProgress)
                Text(
                  '${(progress * 100).round()}%',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF168C95),
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),

            child:
                LinearProgressIndicator(
              value: hasProgress
                  ? progress
                  : null,
              minHeight: 6,
              color:
                  const Color(
                0xFF168C95,
              ),
              backgroundColor:
                  const Color(
                0xFFE2EEEE,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// PÍLDORA DE INFORMACIÓN
// =================================================================

class _InfoPill
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
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
        vertical: 8,
      ),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF1F8F8),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              const Color(0xFFE1EEEE),
        ),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 16,
            color:
                const Color(
              0xFF168C95,
            ),
          ),

          const SizedBox(
            width: 7,
          ),

          Text(
            label,
            style:
                const TextStyle(
              fontSize: 11,
              color:
                  Color(0xFF35545A),
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// ESTADO DE ERROR
// =================================================================

class _ErrorState
    extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width: 75,
              height: 75,
              decoration:
                  const BoxDecoration(
                color:
                    Color(0xFFFFEEEE),
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .error_outline_rounded,
                color:
                    Color(0xFFD64545),
                size: 38,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'No se pudo cargar',
              style:
                  TextStyle(
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
                color:
                    Colors.grey.shade600,
              ),
            ),

            if (onRetry != null) ...[
              const SizedBox(
                height: 18,
              ),

              FilledButton.icon(
                onPressed:
                    onRetry,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label:
                    const Text(
                  'Intentar nuevamente',
                ),
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      const Color(
                    0xFF168C95,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}