import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project_app/notification_services.dart';
import 'package:project_app/splash_screen.dart';
import 'package:shimmer/shimmer.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler (RemoteMessage message)async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paginated List View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
    );
  }
}

class PaginatedListView extends StatefulWidget {
  @override
  PaginatedListViewState createState() => PaginatedListViewState();
}

class PaginatedListViewState extends State<PaginatedListView> {
  final NotificationServices notificationServices = NotificationServices();

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isLoading = false;
  bool hasMore = true;
  bool isThrottling = false;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    notificationServices.requestNotificationPermission();
    notificationServices.forgroundMessage();
    notificationServices.firebaseInit(context);
    notificationServices.setupInteractMessage(context);
    notificationServices.isTokenRefresh();
    // Get device token
    notificationServices.getDeviceToken().then((value){
      if (kDebugMode) {
        print('device token');
        print(value);
      }
    });

    fetchInitialData();

    // Search listener
    searchController.addListener(() {
      filterItems();
    });
  }

  Future<void> fetchInitialData() async {
    setState(() => isLoading = true);
    Map<String, dynamic> response = await fetchItems(100, "down");
    setState(() {
      items.addAll(response["data"]);
      filteredItems = List.from(items);
      isLoading = false;
      hasMore = response["hasMore"];
    });
  }

  Future<void> fetchData(int id, String direction) async {
    if (isLoading || !hasMore || isThrottling) return;

    setState(() => isThrottling = true);
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() => isLoading = true);
    Map<String, dynamic> response = await fetchItems(id, direction);
    setState(() {
      if (direction == "up") {
        items.insertAll(0, response["data"]);
      } else {
        items.addAll(response["data"]);
      }
      filteredItems = List.from(items);
      isLoading = false;
      hasMore = response["hasMore"];
      isThrottling = false;
    });
  }

  void filterItems() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredItems = items.where((item) {
        return item["title"].toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paginated List View'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                    fetchData(items.last["id"], "down");
                  } else if (scrollInfo.metrics.pixels == scrollInfo.metrics.minScrollExtent) {
                    fetchData(items.first["id"], "up");
                  }
                  return false;
                },
                child: ListView.separated(
                  itemCount: filteredItems.length + (isLoading ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == filteredItems.length) {
                      return Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: const ListTile(
                          title: SizedBox(
                            width: double.infinity,
                            height: 16.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white),
                            ),
                          ),
                          subtitle: SizedBox(
                            width: double.infinity,
                            height: 12.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListTile(
                      title: Text(filteredItems[index]["title"]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> fetchItems(int id, String direction) async {
  await Future.delayed(const Duration(seconds: 1));

  List<Map<String, dynamic>> items = [];
  if (direction == "up") {
    for (int j = id - 1; j >= id - 10; j--) {
      if (j < 0) break;
      items.add({"id": j, "title": "Item $j"});
    }
  } else {
    for (int i = id + 1; i <= id + 10; i++) {
      if (i > 2000) break;
      items.add({"id": i, "title": "Item $i"});
    }
  }

  bool hasMore = (direction == "up" && items.isNotEmpty && items.last["id"] > 0) ||
      (direction == "down" && items.isNotEmpty && items.last["id"] < 2000);

  return {"data": items, "hasMore": hasMore};
}
