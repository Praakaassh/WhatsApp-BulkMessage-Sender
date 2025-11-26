import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Clean a phone number:
/// - remove spaces, dashes, brackets, dots, etc.
/// - normalize to +91XXXXXXXXXX when possible (India-focused)
String cleanNumber(String number) {
  number = number.replaceAll(RegExp(r'[^\d+]'), '');
  if (number.startsWith('00')) {
    number = '+${number.substring(2)}';
  }
  if (number.startsWith('0') && number.length >= 11) {
    number = '+91${number.substring(1)}';
  }
  if (!number.startsWith('+') && number.length == 10) {
    number = '+91$number';
  }
  if (number.startsWith('91') && number.length == 12) {
    number = '+$number';
  }
  return number;
}

/// Valid if it matches +91 followed by 10 digits
bool isValidNumber(String number) {
  final cleaned = cleanNumber(number);
  return RegExp(r'^\+91\d{10}$').hasMatch(cleaned);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> contacts = [];
  final TextEditingController newNameController = TextEditingController();
  final TextEditingController newNumberController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final TextEditingController minDelayController = TextEditingController(text: '2');
  final TextEditingController maxDelayController = TextEditingController(text: '4');

  List<File> selectedImages = [];
  List<File> selectedDocs = [];
  String logs = '';
  bool isSending = false;
final String pythonExecutable =
    '${Directory.current.path}\\python_portable\\python.exe';



  final ScrollController _formScrollController = ScrollController();
  final ScrollController _logScrollController = ScrollController();
  
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    loadContacts();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _formScrollController.dispose();
    _logScrollController.dispose();
    _fabController.dispose();
    newNameController.dispose();
    newNumberController.dispose();
    messageController.dispose();
    minDelayController.dispose();
    maxDelayController.dispose();
    super.dispose();
  }

  void appendLog(String text) {
    setState(() {
      logs += text;
      if (!logs.endsWith('\n')) logs += '\n';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      appendLog('⚠ Could not launch $url');
    }
  }

  Future<void> saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_contacts', jsonEncode(contacts));
  }

  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('saved_contacts');
    if (data != null) {
      try {
        final List decoded = jsonDecode(data);
        contacts.clear();
        for (var c in decoded) {
          contacts.add({
            'name': c['name'] ?? '',
            'number': c['number'] ?? '',
            'enabled': c['enabled'] ?? true,
          });
        }
        setState(() {});
        appendLog('📥 Restored ${contacts.length} saved contact(s).');
      } catch (_) {
        appendLog('⚠ Failed to restore saved contacts.');
      }
    }
  }

  void addManualContact() {
    String name = newNameController.text.trim();
    String number = newNumberController.text.trim();

    if (number.isEmpty) {
      _showSnackBar('Phone number cannot be empty', isError: true);
      return;
    }

    final cleaned = cleanNumber(number);
    if (!isValidNumber(cleaned)) {
      _showSnackBar('Invalid number: $cleaned', isError: true);
      return;
    }

    setState(() {
      contacts.add({'name': name, 'number': cleaned, 'enabled': true});
      newNameController.clear();
      newNumberController.clear();
    });
    saveContacts();
    _showSnackBar('Contact added successfully!');
  }

  void removeContact(int index) {
    setState(() {
      contacts.removeAt(index);
    });
    saveContacts();
  }

  void _openEditDialog(int index) {
    final nameCtrl = TextEditingController(text: contacts[index]['name'] ?? '');
    final numCtrl = TextEditingController(text: contacts[index]['number'] ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Edit Contact', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildTextField(nameCtrl, 'Name', Icons.person),
              const SizedBox(height: 16),
              _buildTextField(numCtrl, 'Phone Number', Icons.phone),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final cleaned = cleanNumber(numCtrl.text.trim());
                      if (!isValidNumber(cleaned)) {
                        _showSnackBar('Invalid number: ${numCtrl.text.trim()}', isError: true);
                        return;
                      }
                      setState(() {
                        contacts[index]['name'] = nameCtrl.text.trim();
                        contacts[index]['number'] = cleaned;
                      });
                      saveContacts();
                      Navigator.pop(context);
                      _showSnackBar('Contact updated!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickTxtContacts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (!await file.exists()) return;

    final lines = await file.readAsLines();
    bool startReading = false;
    int imported = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (!startReading) {
        if (line.toLowerCase().startsWith('name')) {
          startReading = true;
        }
        continue;
      }

      final parts = line.split(RegExp(r'\s{2,}|\t+'));
      if (parts.length < 2) continue;

      String name = parts[0].trim();
      String numbersPart = parts[1].trim();
      final numbers = numbersPart.split(',').map((e) => e.trim());

      for (final num in numbers) {
        if (num.isEmpty) continue;
        final cleaned = cleanNumber(num);
        if (!isValidNumber(cleaned)) {
          appendLog('⚠ Skipping invalid number from TXT: $num');
          continue;
        }
        setState(() {
          contacts.add({'name': name, 'number': cleaned, 'enabled': true});
        });
        imported++;
      }
    }

    saveContacts();
    appendLog('📥 Imported $imported contact(s) from TXT file.');
    _showSnackBar('Imported $imported contacts!');
  }

  Future<void> pickCsvContacts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (!await file.exists()) return;

    final lines = await file.readAsLines();
    int imported = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      String name = '';
      String number = '';

      if (parts.length >= 2) {
        name = parts[0].trim();
        number = parts[1].trim();
      } else {
        number = parts[0].trim();
      }

      final cleaned = cleanNumber(number);
      if (!isValidNumber(cleaned)) {
        appendLog('⚠ Skipping invalid number from CSV: $number');
        continue;
      }

      setState(() {
        contacts.add({'name': name, 'number': cleaned, 'enabled': true});
      });
      imported++;
    }

    saveContacts();
    appendLog('📥 Imported $imported contact(s) from CSV file.');
    _showSnackBar('Imported $imported contacts!');
  }

  Future<void> pickImagesReplace() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;

    setState(() {
      selectedImages = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
    });
  }

  Future<void> pickImagesAddMore() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;

    setState(() {
      selectedImages.addAll(
        result.paths.where((p) => p != null).map((p) => File(p!)).toList(),
      );
    });
  }

  Future<void> pickDocsReplace() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result == null) return;

    setState(() {
      selectedDocs = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
    });
  }

  Future<void> pickDocsAddMore() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result == null) return;

    setState(() {
      selectedDocs.addAll(
        result.paths.where((p) => p != null).map((p) => File(p!)).toList(),
      );
    });
  }

  Future<void> exportContactsToTxt() async {
    if (contacts.isEmpty) {
      appendLog('⚠ No contacts to export.');
      _showSnackBar('No contacts to export', isError: true);
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Total Contacts      ${contacts.length}');
    buffer.writeln('Date Created        ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}   ${TimeOfDay.now().format(context)}');
    buffer.writeln('');
    buffer.writeln('Name        Number');
    buffer.writeln('');

    for (final c in contacts) {
      String name = (c['name'] as String).trim();
      String number = (c['number'] as String).trim();
      if (name.isEmpty) name = 'NoName';
      buffer.writeln('$name        $number');
    }

    final content = buffer.toString();
    final output = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Contacts as TXT',
      fileName: 'contacts_export.txt',
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (output == null) {
      appendLog('⚠ Export cancelled.');
      return;
    }

    await File(output).writeAsString(content, encoding: utf8);
    appendLog('📤 Exported ${contacts.length} contact(s) to: $output');
    _showSnackBar('Contacts exported successfully!');
  }

  Future<void> startSending() async {
    final message = messageController.text.trim();
    final bool hasImages = selectedImages.isNotEmpty;
    final bool hasDocs = selectedDocs.isNotEmpty;

    final sendList = contacts.where((c) => (c['enabled'] as bool? ?? true)).toList();

    if (sendList.isEmpty) {
      appendLog('⚠ All contacts are disabled or no contacts added.');
      _showSnackBar('No enabled contacts!', isError: true);
      return;
    }

    for (final c in sendList) {
      final num = c['number'] as String? ?? '';
      if (!isValidNumber(num)) {
        appendLog('❌ Invalid number detected: $num');
        _showSnackBar('Invalid number detected: $num', isError: true);
        return;
      }
    }

    if (message.isEmpty && !hasImages && !hasDocs) {
      appendLog('⚠ Nothing to send. Add text or attachments.');
      _showSnackBar('Add message or attachments!', isError: true);
      return;
    }

    double minDelay = double.tryParse(minDelayController.text.trim()) ?? 2;
    double maxDelay = double.tryParse(maxDelayController.text.trim()) ?? 4;
    if (maxDelay < minDelay) {
      final tmp = minDelay;
      minDelay = maxDelay;
      maxDelay = tmp;
    }

    final tempDir = Directory.systemTemp.createTempSync('wa_sender_');
    final configFile = File('${tempDir.path}${Platform.pathSeparator}config.json');

    final config = {
      'contacts': sendList,
      'message': message,
      'image_paths': selectedImages.map((e) => e.path).toList(),
      'file_paths': selectedDocs.map((e) => e.path).toList(),
      'min_delay': minDelay,
      'max_delay': maxDelay,
    };

    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      encoding: utf8,
    );

    appendLog('✅ Config created at: ${configFile.path}');
    appendLog('👥 Total contacts to send: ${sendList.length}');
    appendLog('🚀 Starting Python sender...');

    setState(() => isSending = true);
    _fabController.forward();

    try {
      final process = await Process.start(
        pythonExecutable,
        ['sender.py', configFile.path],
        runInShell: true,
      );

      process.stdout.transform(utf8.decoder).listen(appendLog);
      process.stderr.transform(utf8.decoder).listen((data) => appendLog('ERR: $data'));

      final exit = await process.exitCode;
      appendLog('Python exited with code $exit');
      _showSnackBar(exit == 0 ? 'Messages sent successfully!' : 'Sending failed!', isError: exit != 0);
    } catch (e) {
      appendLog('❌ Failed to start Python: $e');
      _showSnackBar('Failed to start sender!', isError: true);
    }

    setState(() => isSending = false);
    _fabController.reverse();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF25D366)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF25D366), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildGradientCard({required Widget child, List<Color>? colors}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF075E54).withOpacity(0.05),
              const Color(0xFF25D366).withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF075E54).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WhatsApp Bulk Sender',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Send messages to multiple contacts',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildSocialButton(
                          'https://www.linkedin.com/in/prakash-ps-088455255/',
                          'https://cdn-icons-png.flaticon.com/512/174/174857.png',
                          Icons.link,
                        ),
                        const SizedBox(width: 12),
                        _buildSocialButton(
                          'https://github.com/Praakaassh',
                          'https://cdn-icons-png.flaticon.com/512/25/25231.png',
                          Icons.code,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Panel - Form
                      Expanded(
                        flex: 2,
                        child: _buildGradientCard(
                          child: Scrollbar(
                            thumbVisibility: true,
                            controller: _formScrollController,
                            child: SingleChildScrollView(
                              controller: _formScrollController,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildContactsSection(),
                                  const SizedBox(height: 32),
                                  _buildMessageSection(),
                                  const SizedBox(height: 32),
                                  _buildAttachmentsSection(),
                                  const SizedBox(height: 32),
                                  _buildDelaySection(),
                                  const SizedBox(height: 32),
                                  _buildSendButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Right Panel - Logs
                      Expanded(
                        flex: 1,
                        child: _buildLogsSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String url, String imageUrl, IconData fallbackIcon) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.network(
          imageUrl,
          width: 28,
          height: 28,
          errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 28, color: const Color(0xFF075E54)),
        ),
      ),
    );
  }

  Widget _buildContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.contacts, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Contacts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
            ),
            const Spacer(),
            Text(
              '${contacts.length} total',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Import/Export Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isSending ? null : pickTxtContacts,
                icon: const Icon(Icons.file_download),
                label: const Text('Import TXT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF075E54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isSending ? null : exportContactsToTxt,
                icon: const Icon(Icons.file_upload),
                label: const Text('Export TXT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        
        // Add Contact Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(newNameController, 'Name (optional)', Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(newNumberController, 'Phone Number', Icons.phone),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isSending ? null : addManualContact,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Contacts List
        Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: contacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No contacts yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: contacts.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200, height: 1),
                  itemBuilder: (context, i) {
                    final c = contacts[i];
                    final name = (c['name'] as String?) ?? '';
                    final number = (c['number'] as String?) ?? '';
                    final valid = isValidNumber(number);
                    final enabled = (c['enabled'] as bool?) ?? true;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: valid ? const Color(0xFF25D366).withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        child: Icon(
                          valid ? Icons.check_circle : Icons.error_outline,
                          color: valid ? const Color(0xFF25D366) : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name.isEmpty ? '(No name)' : name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      subtitle: Text(
                        number,
                        style: TextStyle(
                          color: valid ? Colors.grey.shade700 : Colors.red,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: enabled,
                              onChanged: (v) {
                                setState(() {
                                  contacts[i]['enabled'] = v;
                                });
                                saveContacts();
                              },
                              activeColor: const Color(0xFF25D366),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: const Color(0xFF075E54),
                            onPressed: () => _openEditDialog(i),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.red.shade400,
                            onPressed: () => removeContact(i),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.message, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Message',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextField(
            controller: messageController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Type your message here...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images Section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Images',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
            ),
            const Spacer(),
            if (selectedImages.isNotEmpty)
              Text(
                '${selectedImages.length} selected',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (selectedImages.isEmpty)
          ElevatedButton.icon(
            onPressed: isSending ? null : pickImagesReplace,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Pick Images'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF075E54),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              side: BorderSide(color: Colors.grey.shade300),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: isSending ? null : pickImagesAddMore,
                icon: const Icon(Icons.add),
                label: const Text('Add More Images'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: selectedImages.map((img) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            img,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedImages.remove(img);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),

        const SizedBox(height: 32),

        // Documents Section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.description, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Documents',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
            ),
            const Spacer(),
            if (selectedDocs.isNotEmpty)
              Text(
                '${selectedDocs.length} selected',
                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (selectedDocs.isEmpty)
          ElevatedButton.icon(
            onPressed: isSending ? null : pickDocsReplace,
            icon: const Icon(Icons.attach_file),
            label: const Text('Pick Documents'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF075E54),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              side: BorderSide(color: Colors.grey.shade300),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: isSending ? null : pickDocsAddMore,
                icon: const Icon(Icons.add),
                label: const Text('Add More Documents'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: selectedDocs.map((file) {
                    final fileName = file.path.split(Platform.pathSeparator).last;
                    final extension = fileName.split('.').last.toUpperCase();
                    
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF075E54).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description, color: Color(0xFF075E54), size: 20),
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(extension, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red.shade400,
                        onPressed: () {
                          setState(() {
                            selectedDocs.remove(file);
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDelaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delay Between Contacts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Minimum (seconds)', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _buildTextField(minDelayController, 'Min delay', Icons.timer),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maximum (seconds)', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _buildTextField(maxDelayController, 'Max delay', Icons.timer_off),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSendButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: isSending 
            ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
            : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF25D366), Color(0xFF20BA5A)],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isSending ? Colors.grey : const Color(0xFF25D366)).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isSending ? null : startSending,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: isSending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send_rounded, size: 24),
        label: Text(
          isSending ? 'SENDING...' : 'START SENDING',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLogsSection() {
    return _buildGradientCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF075E54), Color(0xFF128C7E)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.terminal, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Activity Logs',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF075E54)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _logScrollController,
                        child: SingleChildScrollView(
                          controller: _logScrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          child: SelectableText(
                            logs.isEmpty ? '⚡ Ready to send messages...' : logs,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: logs.isEmpty ? Colors.grey.shade600 : const Color(0xFF00FF00),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${logs.split('\n').where((l) => l.isNotEmpty).length} entries',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                logs = '';
                              });
                            },
                            icon: const Icon(Icons.clear_all, size: 16),
                            label: const Text('Clear'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
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