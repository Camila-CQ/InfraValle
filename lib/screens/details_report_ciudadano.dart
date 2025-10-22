import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DetailsReportCiudadano extends StatelessWidget {
  final String reportId; 

  const DetailsReportCiudadano({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Reporte'),
        backgroundColor: const Color.fromARGB(255, 110, 197, 159),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('reports').doc(reportId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Reporte no encontrado'));
          }

          var reportData = snapshot.data!.data() as Map<String, dynamic>;

          GeoPoint? geoPoint = reportData['location'];
          LatLng? reportLocation =
              geoPoint != null ? LatLng(geoPoint.latitude, geoPoint.longitude) : null;

          return Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color.fromARGB(255, 110, 197, 159), Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descripción del usuario:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 110, 197, 159),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        reportData['description'] ?? 'Sin descripción',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Estado del reporte:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 110, 197, 159),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        reportData['status'] ?? 'Sin estado',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ubicación del reporte:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 110, 197, 159),
                        ),
                      ),
                      SizedBox(height: 10),
                      reportLocation != null
                          ? SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: reportLocation,
                                  zoom: 15,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId('report-location'),
                                    position: reportLocation,
                                  )
                                },
                              ),
                            )
                          : Text(
                              'Ubicación no disponible',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                      const SizedBox(height: 20),
                      Text(
                        'Fecha:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 110, 197, 159),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        reportData['timestamp'] != null
                            ? reportData['timestamp'].toDate().toString()
                            : 'Desconocida',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
