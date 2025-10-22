import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; 

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController descriptionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageUrl;
  LatLng? _location;

  // Funciones
  Future<void> pickImage() async { 
    Uint8List? pickedFile = await ImagePickerWeb.getImageAsBytes();
    setState(() {
      if (pickedFile != null) {
        _imageBytes = pickedFile;
      }
    });
  }

  Future<void> pickLocation() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar ubicación'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: GoogleMap(
              onTap: (LatLng latLng) {
                setState(() {
                  _location = latLng;
                });
                Navigator.of(context).pop();
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.7749, -122.4194),
                zoom: 10,
              ),
              markers: _location != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected-location'),
                        position: _location!,
                      )
                    }
                  : {},
            ),
          ),
        );
      },
    );
  }

  Future<void> uploadImageAndCreateReport() async {
    if (_imageBytes != null) {
      try {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
        UploadTask uploadTask =
            _storage.ref('report_images/$fileName').putData(_imageBytes!, metadata);
        TaskSnapshot snapshot = await uploadTask;

        _imageUrl = await snapshot.ref.getDownloadURL();

        await _firestore.collection('reports').add({
          'description': descriptionController.text,
          'userId': _auth.currentUser!.uid,
          'imageUrl': _imageUrl,
          'location': _location != null
              ? GeoPoint(_location!.latitude, _location!.longitude)
              : null,
          'timestamp': FieldValue.serverTimestamp(),
        });

        descriptionController.clear();
        setState(() {
          _imageBytes = null;
          _location = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte creado exitosamente')),
        );
      } catch (e) {
        print("Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Reporte'),
        backgroundColor: const Color.fromARGB(255, 183, 231, 194), 
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color.fromARGB(255, 232, 246, 236),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text( //
                'Descripción del Reporte',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Color.fromARGB(104, 0, 0, 0),
                ),
              ),
              const SizedBox(height: 10),  //
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField( //
                      controller: descriptionController, //
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Ingrese la descripción',
                        labelStyle: TextStyle(color: Color.fromARGB(104, 0, 0, 0)),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 15),//
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 110, 
                        decoration: BoxDecoration(
                          color: Colors.green[200], // Usamos verde pastel
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.greenAccent, width: 2),
                        ),
                        child: _imageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover, 
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              )
                            : const Icon(Icons.add_a_photo, size: 40, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Seleccionar Ubicación:',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold, 
                  color: Color.fromARGB(255, 173, 173, 173),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: pickLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 116, 157, 228),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Seleccionar Ubicación en el Mapa',
                  style: TextStyle(fontSize: 16,color: Color.fromARGB(255, 105, 105, 105)),
                ),
              ),
              const SizedBox(height: 20),
              if (_location != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromARGB(255, 116, 157, 228), width: 2),
                  ),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: GoogleMap(
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected-location'),
                          position: _location!,
                        ),
                      },
                      initialCameraPosition: CameraPosition(
                        target: _location!,
                        zoom: 15,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: uploadImageAndCreateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 116, 157, 228),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Enviar Reporte',
                    style: TextStyle(fontSize: 16,color: Color.fromARGB(255, 195, 42, 42)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
