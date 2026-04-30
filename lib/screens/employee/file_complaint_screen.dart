import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/complaint.dart';
import '../../services/complaint_service.dart';
import '../shared/chat_fab.dart';

class FileComplaintScreen extends StatefulWidget {
  const FileComplaintScreen({super.key});

  @override
  State<FileComplaintScreen> createState() => _FileComplaintScreenState();
}

class _FileComplaintScreenState extends State<FileComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _complaintService = ComplaintService();

  bool _isAnonymous = false;
  bool _isLoading = false;
  final List<File> _attachments = [];
  final List<String> _attachmentNames = [];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _attachments.add(File(pickedFile.path));
        _attachmentNames.add(pickedFile.name);
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _attachments.add(File(pickedFile.path));
        _attachmentNames.add(pickedFile.name);
      });
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachments.add(File(result.files.single.path!));
        _attachmentNames.add(result.files.single.name);
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _attachmentNames.removeAt(index);
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Attach Evidence',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D3B66),
                    child: const Icon(Icons.photo_library_rounded,
                        color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  subtitle: const Text('Select an image from your device'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1A7FA0),
                    child:
                        const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  ),
                  title: const Text('Take a Photo'),
                  subtitle: const Text('Capture evidence with camera'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF2E7D32),
                    child: const Icon(Icons.description_rounded,
                        color: Colors.white),
                  ),
                  title: const Text('Upload Document'),
                  subtitle:
                      const Text('PDF, DOC, DOCX, TXT, or image files'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _complaintService.submitComplaint(
        subject: _subjectController.text.trim(),
        description: _descriptionController.text.trim(),
        isAnonymous: _isAnonymous,
        attachments: _attachments,
        attachmentFileNames: _attachmentNames,
      );

      final deptName = result.department == ComplaintDepartment.legal
          ? 'Legal'
          : 'Human Resources';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complaint submitted to $deptName department!',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      String errorText;
      final message = e.toString();
      if (message.contains('too large for Firestore')) {
        errorText =
            'Evidence is too large to store in Firestore. Please attach smaller files.';
      } else {
        errorText = 'Failed to submit complaint: $e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorText),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('File a Complaint'),
        backgroundColor: const Color(0xFF0D3B66),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                elevation: 0,
                color: const Color(0xFF0D3B66).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_rounded,
                        color: Color(0xFF0D3B66),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your complaint will be handled confidentially. You can choose to remain anonymous.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF0D3B66),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // AI classification info card
              Card(
                elevation: 0,
                color: const Color(0xFF1A7FA0).withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF1A7FA0),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The appropriate department (HR or Legal) will be automatically determined based on your complaint.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF1A7FA0),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Anonymous toggle
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Submit Anonymously',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(
                    _isAnonymous
                        ? 'Your identity will be hidden'
                        : 'Your name will be included',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  secondary: Icon(
                    _isAnonymous
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFF0D3B66),
                  ),
                  value: _isAnonymous,
                  activeColor: const Color(0xFF0D3B66),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onChanged: (value) => setState(() => _isAnonymous = value),
                ),
              ),
              const SizedBox(height: 24),

              // Subject
              Text(
                'Subject',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  hintText: 'Brief title for your complaint',
                  prefixIcon: const Icon(Icons.subject_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText:
                      'Provide a detailed description of your complaint...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please describe your complaint';
                  }
                  if (value.length < 20) {
                    return 'Description must be at least 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Attachments Section
              Text(
                'Evidence (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Attach images or documents to support your complaint',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),

              // Attach button
              InkWell(
                onTap: _showAttachmentOptions,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF0D3B66).withOpacity(0.3),
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF0D3B66).withOpacity(0.04),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_rounded,
                        size: 40,
                        color: const Color(0xFF0D3B66).withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to attach files',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D3B66).withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Images, PDF, DOC, DOCX, TXT',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // Attachment list
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                ..._attachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final name = _attachmentNames[index];
                  final isImage = name.toLowerCase().endsWith('.png') ||
                      name.toLowerCase().endsWith('.jpg') ||
                      name.toLowerCase().endsWith('.jpeg');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFF0D3B66).withOpacity(0.1),
                          child: Icon(
                            isImage
                                ? Icons.image_rounded
                                : Icons.description_rounded,
                            color: const Color(0xFF0D3B66),
                          ),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Colors.red.shade400),
                          onPressed: () => _removeAttachment(index),
                        ),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 32),

              // Submit button
              FilledButton(
                onPressed: _isLoading ? null : _submitComplaint,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Complaint',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: const ChatFab(),
    );
  }
}
