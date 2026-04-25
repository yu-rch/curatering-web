import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';
import '../services/user_api.dart';
import '../auth/auth_session.dart';
import '../auth/roles.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String _selectedIssue = 'Select problem';

  final List<String> _issues = [
    'Login issue',
    'Data not loading',
    'Missing Orders',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
  }

  void _onLogout() {
    AuthSession.instance.clear();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthSession.instance.currentUser.value?.role;
    return AppScaffold(
      showSearch: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Session controls and support actions.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _onLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Log out'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (role == Role.superAdmin)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Request Help',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedIssue,
                                    items: [
                                      const DropdownMenuItem(
                                        value: 'Select problem',
                                        child: Text('select problem'),
                                      ),
                                      ..._issues.map(
                                        (issue) => DropdownMenuItem(
                                          value: issue,
                                          child: Text(issue),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedIssue = value;
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _selectedIssue == 'Select problem'
                                      ? null
                                      : () async {
                                          final messenger = ScaffoldMessenger.of(context);
                                          try {
                                            await UserApi.instance.requestHelp(issue: _selectedIssue);
                                            if (!mounted) return;
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Help request sent.')),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Failed to send request.')),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF4511E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  ),
                                  child: const Text('send'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Content Management (prototype)',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
