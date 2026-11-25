import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/lesson_model.dart';
import '../../models/sign_model.dart';
import '../../services/firestore_service.dart';
import '../../services/media_storage_service.dart';
import '../../utils/theme.dart';

const _contentAdminEmail = 'marcronielbisac@gmail.com';

class SignGifManagerScreen extends StatefulWidget {
  const SignGifManagerScreen({super.key});

  @override
  State<SignGifManagerScreen> createState() => _SignGifManagerScreenState();
}

class _SignGifManagerScreenState extends State<SignGifManagerScreen> {
  final _firestore = FirestoreService();
  final Set<String> _savingIds = {};

  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email?.toLowerCase() == _contentAdminEmail;

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: Text('You do not have access to this page.')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Content manager'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          bottom: const TabBar(tabs: [Tab(text: 'Signs'), Tab(text: 'Lessons')]),
        ),
        body: TabBarView(children: [_buildSigns(), _buildLessons()]),
      ),
    );
  }

  Widget _buildSigns() => StreamBuilder<List<SignModel>>(
        stream: _firestore.streamSigns(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _loadError();
          if (!snapshot.hasData) return _loading();
          final signs = snapshot.data!;
          return _contentList(
            emptyLabel: 'No signs yet. Add your first sign.',
            onAdd: () => _editSign(),
            addLabel: 'Add sign',
            itemCount: signs.length,
            itemBuilder: (context, index) {
              final sign = signs[index];
              return _contentCard(
                title: sign.word,
                subtitle: '${sign.category} • ${sign.difficulty}',
                id: sign.id,
                media: [sign.imageUrl, sign.gifUrl, sign.videoUrl],
                onEdit: () => _editSign(sign),
              );
            },
          );
        },
      );

  Widget _buildLessons() => StreamBuilder<List<LessonModel>>(
        stream: _firestore.streamLessons(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _loadError();
          if (!snapshot.hasData) return _loading();
          final lessons = snapshot.data!;
          return _contentList(
            emptyLabel: 'No lessons yet. Add your first lesson.',
            onAdd: () => _editLesson(),
            addLabel: 'Add lesson',
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return _contentCard(
                title: lesson.title,
                subtitle: '${lesson.category} • ${lesson.signIds.length} signs',
                id: lesson.id,
                media: [lesson.imageUrl, lesson.videoUrl],
                onEdit: () => _editLesson(lesson),
              );
            },
          );
        },
      );

  Widget _contentList({
    required String emptyLabel,
    required VoidCallback onAdd,
    required String addLabel,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(addLabel),
            ),
          ),
        ),
        Expanded(
          child: itemCount == 0
              ? Center(child: Text(emptyLabel))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: itemBuilder,
                ),
        ),
      ],
    );
  }

  Widget _contentCard({
    required String title,
    required String subtitle,
    required String id,
    required List<String> media,
    required VoidCallback onEdit,
  }) {
    final isSaving = _savingIds.contains(id);
    final mediaCount = media.where((url) => url.trim().isNotEmpty).length;
    return Card(
      color: Colors.white,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$subtitle\nID: $id • $mediaCount media file${mediaCount == 1 ? '' : 's'}'),
        isThreeLine: true,
        trailing: isSaving
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy document ID',
                    icon: const Icon(Icons.copy_outlined),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: id));
                      _showMessage('Document ID copied.');
                    },
                  ),
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
                ],
              ),
      ),
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator(color: AppColors.primary));

  Widget _loadError() => const Center(child: Text('Could not load content. Check your connection and try again.'));

  Future<void> _editSign([SignModel? sign]) async {
    final id = sign?.id ?? _firestore.newSignId();
    final word = TextEditingController(text: sign?.word ?? '');
    final category = TextEditingController(text: sign?.category ?? '');
    final difficulty = TextEditingController(text: sign?.difficulty ?? 'beginner');
    final imageUrl = TextEditingController(text: sign?.imageUrl ?? '');
    final gifUrl = TextEditingController(text: sign?.gifUrl ?? '');
    final videoUrl = TextEditingController(text: sign?.videoUrl ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(sign == null ? 'Add sign' : 'Edit ${sign.word}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(word, 'Sign name', onChanged: (_) => setDialogState(() {})),
                  _field(category, 'Category'),
                  _field(difficulty, 'Difficulty'),
                  const SizedBox(height: 8),
                  _mediaField(imageUrl, 'Image', 'signs', id, 'images', 'image'),
                  _mediaField(gifUrl, 'GIF', 'signs', id, 'gifs', 'gif'),
                  _mediaField(videoUrl, 'Video', 'signs', id, 'videos', 'video'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: word.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Save sign'),
            ),
          ],
        ),
      ),
    );

    if (save == true) {
      await _saveRecord(id, () => _firestore.saveSign(id, SignModel(
            id: id,
            word: word.text.trim(),
            category: category.text.trim(),
            difficulty: difficulty.text.trim().isEmpty ? 'beginner' : difficulty.text.trim(),
            imageUrl: imageUrl.text.trim(),
            gifUrl: gifUrl.text.trim(),
            videoUrl: videoUrl.text.trim(),
          ).toMap()));
    }
    for (final controller in [word, category, difficulty, imageUrl, gifUrl, videoUrl]) {
      controller.dispose();
    }
  }

  Future<void> _editLesson([LessonModel? lesson]) async {
    final id = lesson?.id ?? _firestore.newLessonId();
    final title = TextEditingController(text: lesson?.title ?? '');
    final category = TextEditingController(text: lesson?.category ?? '');
    final description = TextEditingController(text: lesson?.description ?? '');
    final signIds = TextEditingController(text: lesson?.signIds.join(', ') ?? '');
    final imageUrl = TextEditingController(text: lesson?.imageUrl ?? '');
    final videoUrl = TextEditingController(text: lesson?.videoUrl ?? '');

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(lesson == null ? 'Add lesson' : 'Edit ${lesson.title}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(title, 'Lesson title', onChanged: (_) => setDialogState(() {})),
                _field(category, 'Category (for example: greetings)'),
                _field(description, 'Description', maxLines: 3),
                _field(signIds, 'Sign document IDs, separated by commas', maxLines: 2),
                _mediaField(imageUrl, 'Cover image', 'lessons', id, 'images', 'image'),
                _mediaField(videoUrl, 'Lesson video', 'lessons', id, 'videos', 'video'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: title.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, true),
            child: const Text('Save lesson'),
          ),
        ],
        ),
      ),
    );

    if (save == true) {
      final ids = signIds.text.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toSet().toList();
      await _saveRecord(id, () => _firestore.saveLesson(id, LessonModel(
            id: id,
            title: title.text.trim(),
            category: category.text.trim(),
            description: description.text.trim(),
            signIds: ids,
            imageUrl: imageUrl.text.trim(),
            videoUrl: videoUrl.text.trim(),
          ).toMap()));
    }
    for (final controller in [title, category, description, signIds, imageUrl, videoUrl]) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget _mediaField(
    TextEditingController controller,
    String label,
    String collection,
    String contentId,
    String folder,
    String mediaType,
  ) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(labelText: '$label URL', border: const OutlineInputBorder()),
              ),
            ),
            IconButton(
              tooltip: 'Upload $label',
              onPressed: () => _uploadMedia(controller, collection, contentId, folder, mediaType),
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
      );

  Future<void> _uploadMedia(
    TextEditingController urlController,
    String collection,
    String contentId,
    String folder,
    String mediaType,
  ) async {
    try {
      final XFile? file;
      if (mediaType == 'video') {
        file = await ImagePicker().pickVideo(source: ImageSource.gallery);
      } else if (mediaType == 'image') {
        file = await ImagePicker().pickImage(source: ImageSource.gallery);
      } else {
        file = await ImagePicker().pickMedia();
      }
      if (file == null) return;
      final valid = mediaType == 'video'
          ? MediaStorageService.isVideo(file.name)
          : mediaType == 'gif'
              ? MediaStorageService.isGif(file.name)
              : ['jpg', 'jpeg', 'png', 'webp'].contains(MediaStorageService.fileExtensionFrom(file.name));
      if (!valid) {
        _showMessage('Choose a supported ${mediaType == 'video' ? 'video' : mediaType} file.');
        return;
      }

      final path = MediaStorageService.buildContentStoragePath(
        collection,
        contentId,
        folder,
        MediaStorageService.safeFileName(file.name),
      );
      final task = FirebaseStorage.instance.ref(path).putFile(
            File(file.path),
            SettableMetadata(contentType: MediaStorageService.contentTypeFor(file.name)),
          );
      final snapshot = await task;
      urlController.text = await snapshot.ref.getDownloadURL();
      if (mounted) setState(() {});
      _showMessage('$mediaType uploaded. Save the content to keep its URL.');
    } catch (error) {
      _showMessage('Upload failed: $error');
    }
  }

  Future<void> _saveRecord(String id, Future<void> Function() save) async {
    setState(() => _savingIds.add(id));
    try {
      await save();
      _showMessage('Content saved.');
    } catch (error) {
      _showMessage('Could not save content: $error');
    } finally {
      if (mounted) setState(() => _savingIds.remove(id));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
