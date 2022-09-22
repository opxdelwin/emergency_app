import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LatLng _cameraPosition = const LatLng(24.508894466794636, 78.67783881942158);
  Set<Marker> markers = {};
  Set<Marker> psMarkers = {};
  Set<Marker> hospMarkers = {};

  Marker? closestPS;
  Marker? closestHosp;
  Position? currposition;
  late BitmapDescriptor gasStationIcon;
  late BitmapDescriptor hospitalIcon;
  late BitmapDescriptor policsStationIcon;
  bool isbottomWindowOpen = true;
  GoogleMapController? mapController;

  ///preferences
  bool isPoliceStation = true;
  bool isHospital = true;

  @override
  void initState() {
    super.initState();
    getIcons();
    getCurrLoc();
    addMarkers();
  }

  @override
  void dispose() {
    mapController!.dispose();
    super.dispose();
  }

  void addMarkers() async {
    Set<Marker> privatemarkers = {};
    psMarkers = {};
    hospMarkers = {};

    if (isPoliceStation) await addMarkersPS();

    if (isHospital) await addMarkersHosp();

    privatemarkers.addAll(psMarkers);
    privatemarkers.addAll(hospMarkers);

    setState(() {
      markers = privatemarkers;
    });
  }

  void _onMapCreated(GoogleMapController controller) async {
    setState(() {
      mapController = controller;
    });

    mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: _cameraPosition, zoom: 4)));

    addMarkers();
  }

  void getCurrLoc() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    currposition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    _cameraPosition = LatLng(currposition!.latitude, currposition!.longitude);

    if (mapController != null) {
      mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _cameraPosition, zoom: 13.5)));
    }
  }

  Future<void> addMarkersPS() async {
    LatLngBounds latLngBounds = await mapController!.getVisibleRegion();

    var testData = await FirebaseFirestore.instance
        .collection('police-station')
        .where('geo-loc' as GeoPoint,
            isGreaterThanOrEqualTo: GeoPoint(latLngBounds.southwest.latitude,
                latLngBounds.southwest.longitude))
        .where('geo-loc' as GeoPoint,
            isLessThanOrEqualTo: GeoPoint(latLngBounds.northeast.latitude,
                latLngBounds.northeast.longitude))
        .get();

    print("test-data: $testData");

    var data =
        await FirebaseFirestore.instance.collection('police-station').get();
    for (var element in data.docs) {
      Map<String, dynamic> data = element.data();
      GeoPoint geoPoint = data['geo-loc'] as GeoPoint;

      ///adding first element to closest marker
      if (closestPS == null) {
        closestPS = Marker(
            icon: policsStationIcon,
            markerId: MarkerId(element.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            infoWindow: InfoWindow(
              onTap: () async {
                await launchUrl(
                    Uri(scheme: 'tel', path: '+91${data['phone']}'));
              },
              title: 'PS',
              snippet: data['name'],
            ));
      } else if (const latlong.Distance().as(
              latlong.LengthUnit.Kilometer,
              latlong.LatLng(geoPoint.latitude, geoPoint.longitude),
              latlong.LatLng(currposition!.latitude, currposition!.longitude)) <
          const latlong.Distance().as(
            latlong.LengthUnit.Kilometer,
            latlong.LatLng(currposition!.latitude, currposition!.longitude),
            latlong.LatLng(
                closestPS!.position.latitude, closestPS!.position.longitude),
          )) {
        setState(() {
          closestPS = Marker(
              markerId: MarkerId(element.id),
              position: LatLng(geoPoint.latitude, geoPoint.longitude),
              infoWindow: InfoWindow(
                onTap: () async {
                  await launchUrl(
                      Uri(scheme: 'tel', path: '+91${data['phone']}'));
                },
                title: 'PS',
                snippet: data['name'],
              ));
        });
      }

      setState(() {
        psMarkers.add(Marker(
            icon: policsStationIcon,
            markerId: MarkerId(element.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            infoWindow: InfoWindow(
              onTap: () async {
                await launchUrl(
                    Uri(scheme: 'tel', path: '+91${data['phone']}'));
              },
              title: 'PS',
              snippet: data['name'],
            )));
      });
    }
  }

  Future<void> addMarkersHosp() async {
    var data = await FirebaseFirestore.instance.collection('hospitals').get();
    for (var element in data.docs) {
      Map<String, dynamic> data = element.data();
      GeoPoint geoPoint = data['geo-loc'] as GeoPoint;

      ///adding first element to closest marker
      if (closestHosp == null) {
        closestHosp = Marker(
            icon: hospitalIcon,
            markerId: MarkerId(element.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            infoWindow: InfoWindow(
              onTap: () async {
                await launchUrl(
                    Uri(scheme: 'tel', path: '+91${data['phone']}'));
              },
              title: 'Hospital',
              snippet: data['name'],
            ));
      } else if (const latlong.Distance().as(
              latlong.LengthUnit.Kilometer,
              latlong.LatLng(geoPoint.latitude, geoPoint.longitude),
              latlong.LatLng(currposition!.latitude, currposition!.longitude)) <
          const latlong.Distance().as(
            latlong.LengthUnit.Kilometer,
            latlong.LatLng(currposition!.latitude, currposition!.longitude),
            latlong.LatLng(closestHosp!.position.latitude,
                closestHosp!.position.longitude),
          )) {
        // print('closest changed, new dist: ${const latlong.Distance().as(
        //       latlong.LengthUnit.Meter,
        //       latlong.LatLng(currposition!.latitude, currposition!.longitude),
        //       latlong.LatLng(
        //           closestPS!.position.latitude, closestPS!.position.longitude),
        //     ) / 2},${data['name']}');

        setState(() {
          closestHosp = Marker(
              markerId: MarkerId(element.id),
              position: LatLng(geoPoint.latitude, geoPoint.longitude),
              infoWindow: InfoWindow(
                  onTap: () async {
                    await launchUrl(
                        Uri(scheme: 'tel', path: '+91${data['phone']}'));
                  },
                  title: 'Hospital',
                  snippet: data['name']));
        });
      }

      setState(() {
        hospMarkers.add(Marker(
            icon: hospitalIcon,
            markerId: MarkerId(element.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            infoWindow: InfoWindow(
              onTap: () async {
                await launchUrl(
                    Uri(scheme: 'tel', path: '+91${data['phone']}'));
              },
              title: 'Hospital',
              snippet: data['name'],
            )));
      });
    }
  }

  void getIcons() async {
    gasStationIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(
          size: Size.square(50),
        ),
        'assets/gas_station.png');

    hospitalIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(
          size: Size.square(50),
        ),
        'assets/hospital-location.png');

    policsStationIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(
          size: Size.square(50),
        ),
        'assets/local_police.png');
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        drawer: Drawer(
          backgroundColor: Colors.transparent,
          width: size.width / 1.6,
          child: Container(
            padding: const EdgeInsets.only(left: 25),
            height: size.height,
            decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                color: Color(0xffcbd3e3)),
            child: ListView(
              children: [
                const SizedBox(height: 50),
                GestureDetector(
                  onTap: () => setState(() {
                    isPoliceStation = !isPoliceStation;
                  }),
                  child: Row(
                    children: [
                      Icon(
                        isPoliceStation
                            ? Icons.remove_circle_outline_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      const Text('Police Stations'),
                      const SizedBox(
                        height: 75,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    isHospital = !isHospital;
                  }),
                  child: Row(
                    children: [
                      Icon(
                        isHospital
                            ? Icons.remove_circle_outline_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      const Text('Hospitals')
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            GoogleMap(
              zoomControlsEnabled: false,
              buildingsEnabled: false,
              mapToolbarEnabled: false,
              markers: markers,
              myLocationButtonEnabled: false,
              initialCameraPosition:
                  CameraPosition(target: _cameraPosition, zoom: 11.5),
              myLocationEnabled: true,
              onMapCreated: (controller) => _onMapCreated(controller),
            ),
            Builder(builder: (context) {
              return Positioned(
                top: 16,
                left: 8,
                child: GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const CircleAvatar(
                    backgroundColor: Color(0xff00408b),
                    radius: 30,
                    child: Icon(Icons.layers_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
              );
            }),
            AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: isbottomWindowOpen ? 50 : (size.height / 2.5) + 15,
                right: 15,
                child: CircleAvatar(
                  backgroundColor: const Color(0xff00408b),
                  radius: 25,
                  child: IconButton(
                    onPressed: () => getCurrLoc(),
                    icon: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                    ),
                  ),
                )),
            AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                bottom: isbottomWindowOpen ? 50 : (size.height / 2.5) + 15,
                left: 15,
                child: ElevatedButton(
                  style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(const Color(0xff00408b))),
                  onPressed: () {
                    addMarkers();
                  },
                  child: const Text('get markers'),
                )),
            AnimatedPositioned(
              bottom: isbottomWindowOpen ? -(size.height / 2.5) + 35 : 0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: const BoxDecoration(
                    color: Color(0xffce9461),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )),
                height: size.height / 2.5,
                width: size.width,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          isbottomWindowOpen = !isbottomWindowOpen;
                        });
                      },
                      onVerticalDragUpdate: (t) {
                        if (!t.delta.dy.isNegative) {
                          setState(() {
                            isbottomWindowOpen = true;
                          });
                        } else {
                          setState(() {
                            isbottomWindowOpen = false;
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: size.width / 6,
                        height: 10,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(16)),
                            border: Border.all(width: 0.2)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: 100,
                        width: size.width,
                        decoration: const BoxDecoration(
                            color: Color(0xffe0d8b0),
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 16,
                                  left: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Nearest Police Station',
                                      style: TextStyle(
                                          color: Colors.black, fontSize: 19),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.local_police),
                                        const SizedBox(width: 8),
                                        Text(
                                            isPoliceStation && closestPS != null
                                                ? closestPS!.infoWindow.snippet!
                                                : 'No data')
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(currposition != null &&
                                            isPoliceStation &&
                                            closestPS != null
                                        ? '${const latlong.Distance().as(
                                              latlong.LengthUnit.Kilometer,
                                              latlong.LatLng(
                                                  currposition!.latitude,
                                                  currposition!.longitude),
                                              latlong.LatLng(
                                                  closestPS!.position.latitude,
                                                  closestPS!
                                                      .position.longitude),
                                            ) / 2} Km'
                                        : 'No data'),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                      onTap: () {},
                                      child:
                                          const Icon(Icons.directions_rounded)),
                                  const Expanded(child: SizedBox(height: 15)),
                                  GestureDetector(
                                      onTap: () {
                                        if (isPoliceStation) {
                                          closestPS!.infoWindow.onTap!.call();
                                        }
                                      },
                                      child: const Icon(Icons.call_rounded)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: 100,
                        width: size.width,
                        decoration: const BoxDecoration(
                            color: Color(0xffe0d8b0),
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 16,
                                  bottom: 16,
                                  left: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Nearest Hospital',
                                        style: TextStyle(
                                            color: Colors.black, fontSize: 19)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons.local_hospital_rounded),
                                        const SizedBox(width: 8),
                                        Text(closestHosp != null && isHospital
                                            ? closestHosp!.infoWindow.snippet!
                                            : 'No data')
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(currposition != null &&
                                            isHospital &&
                                            closestHosp != null
                                        ? '${const latlong.Distance().as(
                                              latlong.LengthUnit.Kilometer,
                                              latlong.LatLng(
                                                  currposition!.latitude,
                                                  currposition!.longitude),
                                              latlong.LatLng(
                                                  closestHosp!
                                                      .position.latitude,
                                                  closestHosp!
                                                      .position.longitude),
                                            ) / 2} Km'
                                        : 'No Data'),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                      onTap: () {},
                                      child:
                                          const Icon(Icons.directions_rounded)),
                                  const Expanded(child: SizedBox(height: 15)),
                                  GestureDetector(
                                      onTap: () {
                                        if (isHospital) {
                                          closestHosp!.infoWindow.onTap!.call();
                                        }
                                      },
                                      child: const Icon(Icons.call_rounded)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16)
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
