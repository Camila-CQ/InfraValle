import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // móvil
import 'package:image_picker_web/image_picker_web.dart'; // web
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Estado UI
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  // Campos editables del admin
  String _status = "En progreso";
  final TextEditingController _adminDescController = TextEditingController();

  // Imagen final (post-solución)
  Uint8List? _finalImageBytes;
  String? _finalImageUrlPreview; // Para mostrar la ya existente en el reporte (si hay)

  // Ubicación
  LatLng? _location;

  // ---------- Carga de datos ----------
  Future<DocumentSnapshot<Map<String, dynamic>>> _loadReportDetails() {
    return _firestore.collection('reports').doc(widget.reportId).get()
      .then((snap) => snap as DocumentSnapshot<Map<String, dynamic>>);
  }

  // (opcional) en tiempo real – si lo prefieres, usa esto en lugar de FutureBuilder
  Stream<DocumentSnapshot<Map<String, dynamic>>> _reportStream() {
    return _firestore.collection('reports').doc(widget.reportId).snapshots();
  }

  // ---------- Pick imagen final ----------
  Future<void> _pickFinalImage() async {
    try {
      if (kIsWeb) {
        final Uint8List? picked = await ImagePickerWeb.getImageAsBytes();
        if (picked != null) {
          setState(() {
            _finalImageBytes = picked;
          });
        }
      } else {
        final ImagePicker picker = ImagePicker();
        final XFile? x = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          imageQuality: 85,
        );
        if (x != null) {
          final bytes = await x.readAsBytes();
          setState(() {
            _finalImageBytes = bytes;
          });
        }
      }
    } catch (e) {
      _snack('No se pudo seleccionar la imagen. $e', isError: true);
    }
  }

  void _removeFinalImage() {
    setState(() {
      _finalImageBytes = null;
    });
  }

  // ---------- Upload imagen final ----------
  Future<String?> _uploadFinalImageIfNeeded() async {
    if (_finalImageBytes == null) return _finalImageUrlPreview; // mantener la existente
    try {
      setState(() {
        _uploadProgress = 0.0;
      });
      final fileName = 'final_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref('final_report_images/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = ref.putData(_finalImageBytes!, metadata);

      uploadTask.snapshotEvents.listen((e) {
        if (e.totalBytes > 0) {
          setState(() => _uploadProgress = e.bytesTransferred / e.totalBytes);
        }
      });

      final snap = await uploadTask;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      _snack('Error al subir la imagen final: $e', isError: true);
      return null;
    }
  }

  // ---------- Guardar cambios ----------
  Future<void> _updateReport() async {
    // Confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Actualizar reporte'),
        content: const Text('¿Deseas guardar los cambios en este reporte?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final newUrl = await _uploadFinalImageIfNeeded();
      final data = <String, dynamic>{
        'status': _status,
        'adminDescription': _adminDescController.text.trim().isEmpty
            ? null
            : _adminDescController.text.trim(),
        'finalImageUrl': newUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Limpia campos null para no sobre-escribir si tu regla lo requiere
      data.removeWhere((key, value) => value == null);

      await _firestore.collection('reports').doc(widget.reportId).update(data);

      _snack('✅ Reporte actualizado correctamente');
      if (mounted) Navigator.pop(context); // Regresar a la lista
    } catch (e) {
      _snack('Error al actualizar el reporte: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  @override
  void dispose() {
    _adminDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Variante A: carga única
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _loadReportDetails(),
      builder: (context, snapshot) {
        // Variante B (en tiempo real): comenta lo de arriba y descomenta lo de abajo
        // return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        //   stream: _reportStream(),
        //   builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !(snapshot.data?.exists ?? false)) {
            return Scaffold(
              appBar: _buildAppBar(),
              body: const Center(child: Text('Reporte no encontrado')),
            );
        }

        final doc = snapshot.data!;
        final data = doc.data()!;
        // Set inicial de campos editables (una vez)
        _status = (data['status'] as String?) ?? _status;
        _adminDescController.text = (data['adminDescription'] as String?) ?? _adminDescController.text;
        _finalImageUrlPreview = (data['finalImageUrl'] as String?);
        final initialImageUrl = (data['imageUrl'] as String?);
        final geo = data['location'] as GeoPoint?;
        _location = (geo != null) ? LatLng(geo.latitude, geo.longitude) : null;

        return Scaffold(
          appBar: _buildAppBar(),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color.fromARGB(255, 232, 246, 236),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isSaving) ...[
                      LinearProgressIndicator(
                        value: _uploadProgress == 0.0 ? null : _uploadProgress,
                        minHeight: 6,
                        color: Colors.green[400],
                        backgroundColor: Colors.green[100],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _HeaderCard(
                      description: data['description'] ?? 'Sin descripción',
                      userId: data['userId'] ?? '—',
                      createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
                      status: _status,
                    ),
                    const SizedBox(height: 12),
                    _ImagesSection(
                      initialImageUrl: initialImageUrl,
                      finalImageUrl: _finalImageUrlPreview,
                      finalBytes: _finalImageBytes,
                      onPick: _pickFinalImage,
                      onRemove: _removeFinalImage,
                    ),
                    const SizedBox(height: 12),
                    _LocationSection(location: _location),
                    const SizedBox(height: 12),
                    _StatusAndNotes(
                      status: _status,
                      onStatusChanged: (s) => setState(() => _status = s),
                      adminDescController: _adminDescController,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _updateReport,
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar cambios'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _finalImageBytes = null;
                                    _uploadProgress = 0.0;
                                  });
                                  _adminDescController.clear();
                                },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Detalles del Reporte'),
      backgroundColor: const Color.fromARGB(255, 183, 231, 194),
      actions: [
        IconButton(
          tooltip: 'Ayuda',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('Ayuda'),
                content: Text(
                  'Aquí puedes revisar el reporte, cambiar su estado, '
                  'añadir una descripción de seguimiento y adjuntar una imagen final.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.help_outline, color: Colors.black87),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

// ================== Secciones UI ==================

class _HeaderCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final created = createdAt != null
        ? '${createdAt!.day.toString().padLeft(2, '0')}/${createdAt!.month.toString().padLeft(2, '0')}/${createdAt!.year}'
        : '—';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.description, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      _Pill(icon: Icons.person, label: 'Usuario: $userId'),
                      _Pill(icon: Icons.calendar_today, label: 'Creado: $created'),
                      _Pill(icon: Icons.flag, label: 'Estado: $status'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagesSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Imágenes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _ImageTile(
                        title: 'Inicial',
                        url: initialImageUrl,
                        emptyText: 'Sin imagen inicial',
                      ),
                    ),
                    SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
                    Expanded(
                      child: _FinalImageTile(
                        title: 'Final',
                        url: finalImageUrl,
                        bytes: finalBytes,
                        onPick: onPick,
                        onRemove: onRemove,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String title;
  final String? url;
  final String emptyText;
  const _ImageTile({required this.title, this.url, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            clipBehavior: Clip.antiAlias,
            child: url != null
                ? Ink.image(
                    image: NetworkImage(url!),
                    fit: BoxFit.cover,
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: InteractiveViewer(
                              child: Image.network(url!, fit: BoxFit.contain),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Text(
                      emptyText,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _FinalImageTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasLocal = bytes != null;
    final hasRemote = url != null && !hasLocal;

    Widget content;
    if (hasLocal) {
      content = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (hasRemote) {
      content = Image.network(url!, fit: BoxFit.cover);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 6),
          Text('Sin imagen final', style: TextStyle(color: Colors.grey[600])),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: content,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Row(
                  children: [
                    Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Seleccionar',
                        onPressed: onPick,
                        icon: const Icon(Icons.file_upload, color: Colors.white),
                      ),
                    ),
                    if (hasLocal)
                      const SizedBox(width: 6),
                    if (hasLocal)
                      Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Quitar',
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  final LatLng? location;
  const _LocationSection({required this.location});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ubicación', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (location == null)
              Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text('Sin coordenadas disponibles',
                    style: TextStyle(color: Colors.grey[600])),
              )
            else
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: location!, zoom: 14),
                    markers: {
                      Marker(
                        markerId: const MarkerId('reportLocation'),
                        position: location!,
                      ),
                    },
                    zoomControlsEnabled: true,
                    myLocationButtonEnabled: false,
                    myLocationEnabled: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusAndNotes extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController adminDescController;

  const _StatusAndNotes({
    required this.status,
    required this.onStatusChanged,
    required this.adminDescController,
  });

  static const List<String> _statuses = [
    'Pendiente',
    'En progreso',
    'En mora',
    'Resuelto',
  ];

  Color _chipColor(String s) {
    switch (s) {
      case 'Resuelto':
        return Colors.green[400]!;
      case 'En mora':
        return Colors.orange[400]!;
      case 'En progreso':
        return Colors.blue[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Estado y seguimiento',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((s) {
                final selected = s == status;
                return ChoiceChip(
                  label: Text(s,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                      )),
                  selected: selected,
                  selectedColor: _chipColor(s),
                  onSelected: (_) => onStatusChanged(s),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: adminDescController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Descripción de seguimiento',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.green[700]),
      label: Text(label),
      backgroundColor: Colors.green[50],
      side: BorderSide(color: Colors.green[100]!),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
