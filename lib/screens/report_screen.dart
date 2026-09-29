import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ============================================================
// COLORES OFICIALES DE INFRAVALLE
// ============================================================

const Color kInfraVallePrimary = Color(0xFF27B3BB);
const Color kInfraValleDark = Color(0xFF168F98);
const Color kInfraValleLight = Color(0xFFE7F7F8);
const Color kInfraValleSoft = Color(0xFFD2F1F3);
const Color kInfraValleBorder = Color(0xFFB8E7EA);
const Color kInfraValleDisabled = Color(0xFF7DD5D9);

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController descriptionController =
      TextEditingController();

  Uint8List? _imageBytes;
  String? _imageUrl;
  LatLng? _location;

  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  // ============================================================
  // IMAGEN
  // ============================================================

  Future<void> pickImage() async {
    try {
      Uint8List? picked;

      if (kIsWeb) {
        picked = await ImagePickerWeb.getImageAsBytes();
      } else {
        final ImagePicker picker = ImagePicker();

        final XFile? xfile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          imageQuality: 85,
        );

        if (xfile != null) {
          picked = await xfile.readAsBytes();
        }
      }

      if (picked != null && mounted) {
        setState(() {
          _imageBytes = picked;
        });
      }
    } catch (e) {
      _showSnack(
        'No se pudo seleccionar la imagen.',
        isError: true,
      );
    }
  }

  void removeImage() {
    setState(() {
      _imageBytes = null;
    });
  }

  // ============================================================
  // UBICACIÓN
  // ============================================================

  Future<void> pickLocation() async {
    final selected = await showDialog<LatLng?>(
      context: context,
      builder: (context) => _LocationPickerDialog(
        initial: _location,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _location = selected;
      });
    }
  }

  // ============================================================
  // CREAR REPORTE
  // ============================================================

  Future<void> uploadImageAndCreateReport() async {
    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_imageBytes == null) {
      _showSnack(
        'Debes agregar una fotografía del problema.',
        isError: true,
      );
      return;
    }

    if (_location == null) {
      _showSnack(
        'Debes seleccionar la ubicación del problema.',
        isError: true,
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showSnack(
        'Tu sesión ha expirado. Inicia sesión nuevamente.',
        isError: true,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    try {
      // ----------------------------------------------------------
      // SUBIR IMAGEN
      // ----------------------------------------------------------

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      final ref = _storage.ref(
        'report_images/$fileName',
      );

      final uploadTask = ref.putData(
        _imageBytes!,
        metadata,
      );

      uploadTask.snapshotEvents.listen(
        (event) {
          if (!mounted) return;

          final total = event.totalBytes;

          if (total > 0) {
            setState(() {
              _uploadProgress =
                  event.bytesTransferred / total;
            });
          }
        },
      );

      final snapshot = await uploadTask;

      _imageUrl =
          await snapshot.ref.getDownloadURL();

      // ----------------------------------------------------------
      // CREAR DOCUMENTO EN FIRESTORE
      // ----------------------------------------------------------

      await _firestore.collection('reports').add({
        'description':
            descriptionController.text.trim(),

        'userId': user.uid,

        'imageUrl': _imageUrl,

        'location': GeoPoint(
          _location!.latitude,
          _location!.longitude,
        ),

        'timestamp':
            FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // ----------------------------------------------------------
      // LIMPIAR FORMULARIO
      // ----------------------------------------------------------

      descriptionController.clear();

      setState(() {
        _imageBytes = null;
        _imageUrl = null;
        _location = null;
        _uploadProgress = 0.0;
        _isSubmitting = false;
      });

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _uploadProgress = 0.0;
      });

      _showSnack(
        'No fue posible crear el reporte. '
        'Inténtalo nuevamente.',
        isError: true,
      );
    }
  }

  // ============================================================
  // LIMPIAR FORMULARIO
  // ============================================================

  void clearForm() {
    if (_isSubmitting) return;

    descriptionController.clear();

    setState(() {
      _imageBytes = null;
      _imageUrl = null;
      _location = null;
      _uploadProgress = 0.0;
    });
  }

  // ============================================================
  // MENSAJES
  // ============================================================

  void _showSnack(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
                child: Text(message),
              ),
            ],
          ),

          backgroundColor:
              isError
                  ? Colors.red.shade700
                  : kInfraVallePrimary,

          behavior:
              SnackBarBehavior.floating,

          margin:
              const EdgeInsets.all(16),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // DIÁLOGO REPORTE CREADO
  // ============================================================

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),

          icon: const Icon(
            Icons.check_circle,
            color: kInfraVallePrimary,
            size: 64,
          ),

          title: const Text(
            '¡Reporte creado!',
            textAlign: TextAlign.center,
          ),

          content: const Text(
            'Tu reporte fue registrado correctamente. '
            'Ahora podrás consultar su estado desde tus reportes.',
            textAlign: TextAlign.center,
          ),

          actionsAlignment:
              MainAxisAlignment.center,

          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },

              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    kInfraVallePrimary,

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),

              child: const Text(
                'Aceptar',
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
    descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F8F9),

      appBar: AppBar(
        elevation: 0,
        centerTitle: false,

        backgroundColor:
            kInfraVallePrimary,

        foregroundColor:
            Colors.white,

        title: const Text(
          'Crear reporte',

          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final bool isWide =
                constraints.maxWidth >= 850;

            return SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(
                horizontal:
                    isWide ? 40 : 16,
                vertical: 24,
              ),

              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 1100,
                  ),

                  child: Form(
                    key: _formKey,

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        _buildHeader(),

                        const SizedBox(
                          height: 24,
                        ),

                        if (_isSubmitting) ...[
                          _buildUploadProgress(),

                          const SizedBox(
                            height: 20,
                          ),
                        ],

                        if (isWide)
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,

                            children: [
                              Expanded(
                                child:
                                    _buildDescriptionCard(
                                  theme,
                                ),
                              ),

                              const SizedBox(
                                width: 20,
                              ),

                              Expanded(
                                child:
                                    _buildImageCard(),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildDescriptionCard(
                                theme,
                              ),

                              const SizedBox(
                                height: 20,
                              ),

                              _buildImageCard(),
                            ],
                          ),

                        const SizedBox(
                          height: 20,
                        ),

                        _buildLocationCard(),

                        const SizedBox(
                          height: 24,
                        ),

                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ENCABEZADO
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(22),

      decoration:
          BoxDecoration(
        color:
            kInfraVallePrimary,

        borderRadius:
            BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.08,
            ),

            blurRadius: 12,

            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Icon(
                Icons
                    .report_problem_outlined,

                color:
                    Colors.white,

                size: 30,
              ),

              SizedBox(
                width: 12,
              ),

              Expanded(
                child: Text(
                  'Reportar problema de infraestructura',

                  style: TextStyle(
                    color:
                        Colors.white,

                    fontSize: 21,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height: 10,
          ),

          Text(
            'Describe el problema, adjunta una fotografía '
            'y señala su ubicación para que pueda ser gestionado.',

            style: TextStyle(
              color:
                  Colors.white,

              height: 1.4,

              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESO
  // ============================================================

  Widget _buildUploadProgress() {
    final percentage =
        (_uploadProgress * 100)
            .clamp(0, 100)
            .toInt();

    return Card(
      elevation: 0,

      color:
          Colors.white,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),

        side:
            BorderSide(
          color:
              kInfraValleSoft,
        ),
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(18),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,

                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.5,

                    color:
                        kInfraVallePrimary,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                const Expanded(
                  child: Text(
                    'Enviando reporte...',

                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  '$percentage%',

                  style:
                      const TextStyle(
                    color:
                        kInfraVallePrimary,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),

              child:
                  LinearProgressIndicator(
                value:
                    _uploadProgress == 0
                        ? null
                        : _uploadProgress,

                minHeight: 7,

                color:
                    kInfraVallePrimary,

                backgroundColor:
                    kInfraValleSoft,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'No cierres esta pantalla mientras se procesa el reporte.',

              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DESCRIPCIÓN
  // ============================================================

  Widget _buildDescriptionCard(
    ThemeData theme,
  ) {
    return _SectionCard(
      title:
          '1. Describe el problema',

      icon:
          Icons.description_outlined,

      child:
          TextFormField(
        controller:
            descriptionController,

        enabled:
            !_isSubmitting,

        maxLines:
            7,

        maxLength:
            500,

        textCapitalization:
            TextCapitalization.sentences,

        decoration:
            InputDecoration(
          hintText:
              'Ejemplo: El semáforo de la calle presenta fallas...',

          filled:
              true,

          fillColor:
              const Color(0xFFF8FAF9),

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),

            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),

            borderSide:
                BorderSide(
              color:
                  Colors.grey.shade300,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),

            borderSide:
                const BorderSide(
              color:
                  kInfraVallePrimary,

              width: 2,
            ),
          ),

          alignLabelWithHint:
              true,
        ),

        validator:
            (value) {
          final text =
              value?.trim() ?? '';

          if (text.isEmpty) {
            return
                'La descripción es obligatoria.';
          }

          if (text.length < 10) {
            return
                'Describe el problema con un poco más de detalle.';
          }

          return null;
        },
      ),
    );
  }

  // ============================================================
  // IMAGEN
  // ============================================================

  Widget _buildImageCard() {
    return _SectionCard(
      title:
          '2. Adjunta una fotografía',

      icon:
          Icons.photo_camera_outlined,

      child:
          Column(
        children: [
          _ImagePickerCard(
            imageBytes:
                _imageBytes,

            onPick:
                _isSubmitting
                    ? () {}
                    : pickImage,

            onRemove:
                _isSubmitting
                    ? () {}
                    : removeImage,
          ),

          const SizedBox(
            height: 12,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.info_outline,

                size: 18,

                color:
                    kInfraVallePrimary,
              ),

              const SizedBox(
                width: 8,
              ),

              const Expanded(
                child: Text(
                  'La fotografía ayuda a identificar y evaluar '
                  'el problema reportado.',

                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UBICACIÓN
  // ============================================================

  Widget _buildLocationCard() {
    return _SectionCard(
      title:
          '3. Señala la ubicación',

      icon:
          Icons.location_on_outlined,

      child:
          Column(
        children: [
          Container(
            width:
                double.infinity,

            padding:
                const EdgeInsets.all(16),

            decoration:
                BoxDecoration(
              color:
                  _location == null
                      ? Colors.orange.shade50
                      : kInfraValleLight,

              borderRadius:
                  BorderRadius.circular(14),

              border:
                  Border.all(
                color:
                    _location == null
                        ? Colors.orange.shade200
                        : kInfraValleBorder,
              ),
            ),

            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(10),

                  decoration:
                      BoxDecoration(
                    color:
                        _location == null
                            ? Colors.orange.shade100
                            : kInfraValleSoft,

                    shape:
                        BoxShape.circle,
                  ),

                  child:
                      Icon(
                    _location == null
                        ? Icons.location_searching
                        : Icons.location_on,

                    color:
                        _location == null
                            ? Colors.orange.shade800
                            : kInfraValleDark,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        _location == null
                            ? 'No has seleccionado una ubicación'
                            : 'Ubicación seleccionada',

                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        _location == null
                            ? 'Selecciona en el mapa el lugar donde ocurre el problema.'
                            : '${_location!.latitude.toStringAsFixed(5)}, '
                              '${_location!.longitude.toStringAsFixed(5)}',

                        style:
                            const TextStyle(
                          fontSize: 13,

                          color:
                              Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      _isSubmitting
                          ? null
                          : pickLocation,

                  icon:
                      const Icon(
                    Icons.map_outlined,
                  ),

                  label:
                      Text(
                    _location == null
                        ? 'Seleccionar ubicación'
                        : 'Cambiar ubicación',
                  ),

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        kInfraVallePrimary,

                    foregroundColor:
                        Colors.white,

                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                    ),

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              if (_location != null) ...[
                const SizedBox(
                  width: 10,
                ),

                IconButton(
                  tooltip:
                      'Quitar ubicación',

                  onPressed:
                      _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _location =
                                    null;
                              });
                            },

                  style:
                      IconButton.styleFrom(
                    backgroundColor:
                        Colors.red.shade50,

                    foregroundColor:
                        Colors.red.shade700,
                  ),

                  icon:
                      const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTONES
  // ============================================================

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width:
              double.infinity,

          child:
              FilledButton.icon(
            onPressed:
                _isSubmitting
                    ? null
                    : uploadImageAndCreateReport,

            icon:
                _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,

                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,

                          color:
                              Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                      ),

            label:
                Text(
              _isSubmitting
                  ? 'Enviando reporte...'
                  : 'Crear reporte',
            ),

            style:
                FilledButton.styleFrom(
              backgroundColor:
                  kInfraVallePrimary,

              foregroundColor:
                  Colors.white,

              disabledBackgroundColor:
                  kInfraValleDisabled,

              padding:
                  const EdgeInsets.symmetric(
                vertical: 16,
              ),

              textStyle:
                  const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(
          height: 10,
        ),

        SizedBox(
          width:
              double.infinity,

          child:
              OutlinedButton.icon(
            onPressed:
                _isSubmitting
                    ? null
                    : clearForm,

            icon:
                const Icon(
              Icons.refresh,
            ),

            label:
                const Text(
              'Limpiar formulario',
            ),

            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  kInfraVallePrimary,

              side:
                  const BorderSide(
                color:
                    kInfraValleDisabled,
              ),

              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
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
    );
  }
}

// ============================================================
// TARJETA DE SECCIÓN
// ============================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      elevation: 0,

      color:
          Colors.white,

      margin:
          EdgeInsets.zero,

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),

        side:
            BorderSide(
          color:
              Colors.grey.shade200,
        ),
      ),

      child:
          Padding(
        padding:
            const EdgeInsets.all(18),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(8),

                  decoration:
                      BoxDecoration(
                    color:
                        kInfraValleLight,

                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),

                  child:
                      Icon(
                    icon,

                    color:
                        kInfraVallePrimary,

                    size: 22,
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      Text(
                    title,

                    style:
                        const TextStyle(
                      fontSize: 17,

                      fontWeight:
                          FontWeight.bold,
                    ),
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

// ============================================================
// TARJETA DE IMAGEN
// ============================================================

class _ImagePickerCard
    extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.imageBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasImage =
        imageBytes != null;

    return GestureDetector(
      onTap:
          hasImage
              ? null
              : onPick,

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 250,
        ),

        height: 250,

        width:
            double.infinity,

        decoration:
            BoxDecoration(
          color:
              hasImage
                  ? Colors.black
                  : const Color(
                      0xFFF1F9FA,
                    ),

          borderRadius:
              BorderRadius.circular(
            16,
          ),

          border:
              Border.all(
            color:
                hasImage
                    ? kInfraVallePrimary
                    : kInfraValleBorder,

            width: 1.5,
          ),
        ),

        child:
            Stack(
          children: [
            Positioned.fill(
              child:
                  ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),

                child:
                    hasImage
                        ? Image.memory(
                            imageBytes!,
                            fit:
                                BoxFit.cover,
                          )
                        : InkWell(
                            onTap:
                                onPick,

                            child:
                                Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,

                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    16,
                                  ),

                                  decoration:
                                      const BoxDecoration(
                                    color:
                                        kInfraValleSoft,

                                    shape:
                                        BoxShape.circle,
                                  ),

                                  child:
                                      const Icon(
                                    Icons
                                        .add_a_photo_outlined,

                                    size:
                                        38,

                                    color:
                                        kInfraVallePrimary,
                                  ),
                                ),

                                const SizedBox(
                                  height: 14,
                                ),

                                const Text(
                                  'Agregar fotografía',

                                  style:
                                      TextStyle(
                                    fontSize:
                                        16,

                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 5,
                                ),

                                const Text(
                                  'Selecciona una imagen del dispositivo',

                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,

                                    color:
                                        Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),

            if (hasImage)
              Positioned(
                top: 10,
                right: 10,

                child:
                    Material(
                  color:
                      Colors.black.withOpacity(
                    0.65,
                  ),

                  shape:
                      const CircleBorder(),

                  child:
                      InkWell(
                    onTap:
                        onRemove,

                    customBorder:
                        const CircleBorder(),

                    child:
                        const Padding(
                      padding:
                          EdgeInsets.all(
                        9,
                      ),

                      child:
                          Icon(
                        Icons
                            .delete_outline,

                        color:
                            Colors.white,

                        size:
                            21,
                      ),
                    ),
                  ),
                ),
              ),

            if (hasImage)
              Positioned(
                left: 10,
                bottom: 10,

                child:
                    Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.black.withOpacity(
                      0.65,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),

                  child:
                      const Row(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      Icon(
                        Icons.check_circle,

                        color:
                            Colors.white,

                        size:
                            16,
                      ),

                      SizedBox(
                        width: 6,
                      ),

                      Text(
                        'Fotografía seleccionada',

                        style:
                            TextStyle(
                          color:
                              Colors.white,

                          fontSize:
                              12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DIÁLOGO DE UBICACIÓN
// ============================================================

class _LocationPickerDialog
    extends StatefulWidget {
  final LatLng? initial;

  const _LocationPickerDialog({
    this.initial,
  });

  @override
  State<_LocationPickerDialog>
      createState() =>
          _LocationPickerDialogState();
}

class _LocationPickerDialogState
    extends State<_LocationPickerDialog> {
  late LatLng _current;

  @override
  void initState() {
    super.initState();

    _current =
        widget.initial ??
        const LatLng(
          10.4760,
          -73.2596,
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final markers = {
      Marker(
        markerId:
            const MarkerId(
          'selected',
        ),

        position:
            _current,

        draggable:
            true,

        onDragEnd:
            (pos) {
          setState(() {
            _current =
                pos;
          });
        },
      ),
    };

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      titlePadding:
          const EdgeInsets.fromLTRB(
        24,
        22,
        24,
        8,
      ),

      contentPadding:
          const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        8,
      ),

      actionsPadding:
          const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        18,
      ),

      title:
          const Row(
        children: [
          Icon(
            Icons.location_on,

            color:
                kInfraVallePrimary,
          ),

          SizedBox(
            width: 10,
          ),

          Text(
            'Seleccionar ubicación',

            style:
                TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),

      content:
          SizedBox(
        width: 600,
        height: 420,

        child:
            ClipRRect(
          borderRadius:
              BorderRadius.circular(
            14,
          ),

          child:
              GoogleMap(
            initialCameraPosition:
                CameraPosition(
              target:
                  _current,

              zoom:
                  14,
            ),

            markers:
                markers,

            onTap:
                (pos) {
              setState(() {
                _current =
                    pos;
              });
            },

            myLocationEnabled:
                false,

            myLocationButtonEnabled:
                false,

            zoomControlsEnabled:
                true,

            mapToolbarEnabled:
                false,
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(null);
          },

          child:
              const Text(
            'Cancelar',
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(
              context,
            ).pop(
              _current,
            );
          },

          icon:
              const Icon(
            Icons.check,
          ),

          label:
              const Text(
            'Usar esta ubicación',
          ),

          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                kInfraVallePrimary,

            foregroundColor:
                Colors.white,

            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}