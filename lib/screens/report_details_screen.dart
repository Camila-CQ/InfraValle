import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  _ReportDetailsScreenState createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Uint8List? _finalImageBytes;
  String? _finalImageUrl;
  String _status = "En progreso";
  final TextEditingController descriptionController = TextEditingController();
  LatLng? _location;

  Future<DocumentSnapshot> _loadReportDetails() async {
    return await _firestore.collection('reports').doc(widget.reportId).get();
  }

  Future<void> pickFinalImage() async {
    Uint8List? pickedFile = await ImagePickerWeb.getImageAsBytes();
    setState(() {
      if (pickedFile != null) {
        _finalImageBytes = pickedFile;
      }
    });
  }

  Future<void> uploadFinalImage() async {
    if (_finalImageBytes != null) {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      try {
        UploadTask uploadTask = _storage.ref('final_report_images/$fileName').putData(_finalImageBytes!);
        TaskSnapshot snapshot = await uploadTask;
        _finalImageUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        print("Error al subir la imagen: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir la imagen')),
        );
      }
    }
  }

  Future<void> updateReport() async {
    await uploadFinalImage();
    try {
      await _firestore.collection('reports').doc(widget.reportId).update({
        'status': _status,
        'finalImageUrl': _finalImageUrl,
        'adminDescription': descriptionController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte actualizado exitosamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Error al actualizar el reporte: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al actualizar el reporte')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _loadReportDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Reporte no encontrado'));
        }

        var reportData = snapshot.data!;
        GeoPoint location = reportData['location'];
        _location = LatLng(location.latitude, location.longitude);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalles del Reporte'),
            backgroundColor: const Color.fromARGB(255, 110, 197, 159),
          ),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color.fromARGB(255, 110, 197, 159), const Color.fromARGB(255, 110, 197, 159)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Descripción del usuario: ${reportData['description']}',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (_location != null)
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _location!,
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('reportLocation'),
                            position: _location!,
                          ),
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  DropdownButton<String>(
                    value: _status,
                    dropdownColor: const Color.fromARGB(255, 70, 210, 210),
                    onChanged: (String? newValue) {
                      setState(() {
                        _status = newValue!;
                      });
                    },
                    items: <String>['En progreso', 'Resuelto', 'Pendiente', 'En mora']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Descripción de seguimiento',
                      labelStyle: TextStyle(color: Colors.white),
                    ),
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: pickFinalImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 70, 210, 210),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: Text(_finalImageBytes != null ? 'Imagen final seleccionada' : 'Subir imagen final'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: updateReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    child: const Text('Actualizar Reporte'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
