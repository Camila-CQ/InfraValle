import 'dart:typed_data';
import 'dart:io' show Platform; // Sólo se usa en móvil
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Opcional si quieres "usar mi ubicación": geolocator (agrega dependencia)
// import 'package:geolocator/geolocator.dart';

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
  final TextEditingController descriptionController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageUrl;
  LatLng? _location;

  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  // ---------- Imagen ----------
  Future<void> pickImage() async {
    try {
      if (kIsWeb) {
        final Uint8List? picked = await ImagePickerWeb.getImageAsBytes();
        if (picked != null) {
          setState(() => _imageBytes = picked);
        }
      } else {
        // Móvil
        final ImagePicker picker = ImagePicker();
        final XFile? xfile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          imageQuality: 85,
        );
        if (xfile != null) {
          final bytes = await xfile.readAsBytes();
          setState(() => _imageBytes = bytes);
        }
      }
    } catch (e) {
      _showSnack('No se pudo seleccionar la imagen. $e', isError: true);
    }
  }

  void removeImage() {
    setState(() => _imageBytes = null);
  }

  // ---------- Ubicación ----------
  Future<void> pickLocation() async {
    final selected = await showDialog<LatLng?>(
      context: context,
      builder: (context) => _LocationPickerDialog(initial: _location),
    );
    if (selected != null) {
      setState(() => _location = selected);
    }
  }

  // (Opcional) Obtener ubicación actual con geolocator
  // Future<LatLng?> _determinePosition() async {
  //   bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  //   if (!serviceEnabled) return null;
  //   LocationPermission permission = await Geolocator.checkPermission();
  //   if (permission == LocationPermission.denied) {
  //     permission = await Geolocator.requestPermission();
  //     if (permission == LocationPermission.denied) return null;
  //   }
  //   if (permission == LocationPermission.deniedForever) return null;
  //   final pos = await Geolocator.getCurrentPosition();
  //   return LatLng(pos.latitude, pos.longitude);
  // }

  // ---------- Upload + Reporte ----------
  Future<void> uploadImageAndCreateReport() async {
    // Validación del formulario
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showSnack('Por favor, completa los campos requeridos.', isError: true);
      return;
    }
    if (_imageBytes == null) {
      _showSnack('Agrega al menos una imagen para el reporte.', isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    try {
      // Subir imagen con progreso
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final ref = _storage.ref('report_images/$fileName');
      final uploadTask = ref.putData(_imageBytes!, metadata);

      uploadTask.snapshotEvents.listen((event) {
        final total = event.totalBytes;
        final transferred = event.bytesTransferred;
        if (total > 0) {
          setState(() => _uploadProgress = transferred / total);
        }
      });

      final snapshot = await uploadTask;
      _imageUrl = await snapshot.ref.getDownloadURL();

      // Crear documento en Firestore
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Sesión no válida. Inicia sesión de nuevo.');
      }

      await _firestore.collection('reports').add({
        'description': descriptionController.text.trim(),
        'userId': user.uid,
        'imageUrl': _imageUrl,
        'location': _location != null
            ? GeoPoint(_location!.latitude, _location!.longitude)
            : null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Reset UI
      descriptionController.clear();
      setState(() {
        _imageBytes = null;
        _location = null;
        _uploadProgress = 0.0;
        _isSubmitting = false;
      });

      _showSnack('✅ Reporte creado exitosamente');
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showSnack('Error al crear el reporte: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Reporte'),
        backgroundColor: const Color.fromARGB(255, 183, 231, 194),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color.fromARGB(255, 232, 246, 236),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 720;
                  final left = _buildLeftColumn(context);
                  final right = _buildRightColumn(context);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isSubmitting) ...[
                        LinearProgressIndicator(
                          value: _uploadProgress == 0.0 ? null : _uploadProgress,
                          minHeight: 6,
                          color: Colors.green[400],
                          backgroundColor: Colors.green[100],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        'Descripción del Reporte',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(104, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right),
                          ],
                        )
                      else
                        Column(
                          children: [
                            left,
                            const SizedBox(height: 16),
                            right,
                          ],
                        ),
                      const SizedBox(height: 16),
                      _buildActionBar(context),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------- UI Secciones ----------
  Widget _buildLeftColumn(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: descriptionController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Ingrese la descripción',
            labelStyle: TextStyle(color: Color.fromARGB(104, 0, 0, 0)),
            fillColor: Colors.white,
            filled: true,
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La descripción es obligatoria';
            }
            if (value.trim().length < 10) {
              return 'Describe un poco más (mínimo 10 caracteres)';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _LocationPreview(
          location: _location,
          onPick: pickLocation,
          onClear: () => setState(() => _location = null),
        ),
      ],
    );
  }

  Widget _buildRightColumn(BuildContext context) {
    return _ImagePickerCard(
      imageBytes: _imageBytes,
      onPick: pickImage,
      onRemove: removeImage,
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Crear reporte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _isSubmitting ? null : uploadImageAndCreateReport,
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Limpiar'),
          onPressed: _isSubmitting
              ? null
              : () {
                  descriptionController.clear();
                  setState(() {
                    _imageBytes = null;
                    _location = null;
                    _uploadProgress = 0.0;
                  });
                },
        ),
      ],
    );
  }
}

// =================== Widgets Auxiliares ===================

class _ImagePickerCard extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ImagePickerCard({
    required this.imageBytes,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.green[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent, width: 2),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageBytes != null
                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.add_a_photo,
                            size: 48, color: Colors.white),
                      ),
              ),
            ),
            if (imageBytes != null)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child:
                          Icon(Icons.delete_forever, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationPreview extends StatelessWidget {
  final LatLng? location;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _LocationPreview({
    required this.location,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.green),
        title: Text(
          location == null
              ? 'Sin ubicación seleccionada'
              : 'Ubicación: ${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
        ),
        subtitle: const Text('Toca "Seleccionar" para definirla en el mapa'),
        trailing: Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: onPick,
              child: const Text('Seleccionar'),
            ),
            if (location != null)
              TextButton(
                onPressed: onClear,
                child: const Text('Quitar'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Diálogo de selección de ubicación ----------
class _LocationPickerDialog extends StatefulWidget {
  final LatLng? initial;
  const _LocationPickerDialog({this.initial});

  @override
  State<_LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<_LocationPickerDialog> {
  late LatLng _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initial ?? const LatLng(10.4760, -73.2596); // Valledupar aprox.
  }

  @override
  Widget build(BuildContext context) {
    final markers = {
      Marker(
        markerId: const MarkerId('selected'),
        position: _current,
        draggable: true,
        onDragEnd: (pos) => setState(() => _current = pos),
      )
    };

    return AlertDialog(
      title: const Text('Seleccionar ubicación'),
      content: SizedBox(
        width: 520,
        height: 380,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _current, zoom: 14),
          markers: markers,
          onTap: (pos) => setState(() => _current = pos),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_current),
          child: const Text('Usar esta ubicación'),
        ),
      ],
    );
  }
}