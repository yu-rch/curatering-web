import 'package:flutter/material.dart';
import '../widgets/app_scaffold1.dart';

class HelpRequestsPage extends StatelessWidget {
  const HelpRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();

    return AppScaffold1(
      searchController: searchController,
      showSearch: true,
      onSearchChanged: (query) {
        // TODO: implement search logic
        debugPrint("Searching for: $query");
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Accounts list
            Expanded(
              flex: 2,
              child: Card(
                elevation: 2,
                child: ListView(
                  children: const [
                    ListTile(
                      title: Text("Hannah Drex Rebancos"),
                      subtitle: Text("ID: 2222-14325"),
                    ),
                    Divider(),
                    ListTile(
                      title: Text("Hannah Drex Rebancos"),
                      subtitle: Text("ID: 2222-14325"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            // User Details + Help Requests
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("User Details",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 12),
                          Text("User: Hannah Drex Rebancos"),
                          Text("Birthday: 11-16-02"),
                          Text("Status: Regular"),
                          Text("Contact No.: 09123456789"),
                          Text("Duration: 1 year"),
                          Text("Role: Supervisor"),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Help Requests",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 12),
                          Text("Feature: Liveboards"),
                          Text("Problem: Not updating"),
                          Text("Request: Update liveboards"),
                          Text("Date and Time: 03-01-2026 15:34"),
                          Text("Status: Unresolved",
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
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
