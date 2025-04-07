import 'package:Gessential/core/config/env_config.dart';
import 'package:flutter/material.dart';
import 'package:Gessential/presentation/screens/home_screen.dart';
import '../../core/services/speech_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/tag_generator_service.dart';
import '../../core/services/settings_service.dart';
import '../../domain/entities/note.dart';
import 'package:intl/intl.dart';
import '../screens/settings_screen.dart';
import 'dart:async';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final SpeechService _speechService = SpeechService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final TagGeneratorService _tagGenerator = TagGeneratorService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  List<Note> _notes = [];
  bool _isInitialized = false;
  bool _isGeneratingTags = false;
  String _selectedLocaleId = SpeechService.englishLocaleId;
  StreamSubscription? _localeSubscription;
  final TextEditingController _textController = TextEditingController();
  bool _hasGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    _initServicesAndStartRecording();
    _loadNotes();

    // Get the current locale from settings
    _selectedLocaleId = _settingsService.selectedLocaleId;

    // Listen for locale changes from other screens
    _localeSubscription = _settingsService.localeStream.listen((localeId) {
      if (mounted && _selectedLocaleId != localeId) {
        setState(() {
          _selectedLocaleId = localeId;
        });
      }
    });
  }

  Future<void> _initServicesAndStartRecording() async {
    // Initialize services first
    await _initServices();

    // Then check if we should start recording
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args?['startRecording'] == true && _isInitialized) {
        _startListening();
      }
    });
  }

  Future<void> _initServices() async {
    final initialized = await _speechService.initialize();

    _hasGeminiApiKey = await EnvConfig.hasValidGeminiApiKey();

    if (mounted) {
      setState(() {
        _isInitialized = initialized;
      });
    }
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await _databaseService.getNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading notes: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;

    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await _speechService.startListening(
      (recognizedWords) async {
        if (!mounted) return;
        if (recognizedWords.isNotEmpty) {
          setState(() => _isGeneratingTags = true);

          try {
            // Generate tags using Gemini
            final tags = await _tagGenerator.generateTags(recognizedWords);
            
            if (!mounted) return;

            // Create and save the note with tags
            final note = Note(content: recognizedWords, tags: tags);
            await _databaseService.createNote(note);
            await _loadNotes();

            if (!mounted) return;
            setState(() => _isGeneratingTags = false);
          } catch (e) {
            if (!mounted) return;
            setState(() => _isGeneratingTags = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating tags: ${e.toString()}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      localeId: _selectedLocaleId,
    );
    if (mounted) setState(() {}); // Update UI to reflect listening state
  }

  Future<void> _deleteNote(Note note) async {
    if (note.id != null) {
      await _databaseService.deleteNote(note.id!);
      await _loadNotes();
    }
  }

  Future<void> _showDeleteAllConfirmation() async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Delete All Notes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to delete all notes?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You will lose all your recorded notes and their tags.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteAllNotes();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Delete All'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllNotes() async {
    if (_notes.isEmpty) return;

    setState(() => _isGeneratingTags = true); // Show loading indicator

    try {
      await _databaseService.deleteAllNotes();
      await _loadNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notes have been deleted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notes: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingTags = false); // Hide loading indicator
      }
    }
  }

  Future<void> _openTextNoteDialog() async {
    _textController.clear();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add Note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type your note here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: null,
                      minLines: 5,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tags will be automatically generated based on the content of your note.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final noteText = _textController.text.trim();
                    if (noteText.isNotEmpty) {
                      setState(() => _isGeneratingTags = true);
                      Navigator.pop(context);

                      // Generate tags using Gemini
                      final tags = await _tagGenerator.generateTags(noteText);

                      // Create and save the note with tags
                      final note = Note(content: noteText, tags: tags);
                      await _databaseService.createNote(note);
                      await _loadNotes();

                      setState(() => _isGeneratingTags = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _editNote(Note note) async {
    _textController.text = note.content;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
              ),
            ],
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last edited: ${DateFormat('MMM d, y HH:mm').format(note.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Edit your note...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: null,
                      minLines: 5,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Current tags:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: note.tags.map((tag) {
                      return Chip(
                        label: Text(tag),
                        backgroundColor:
                            Theme.of(context).colorScheme.secondaryContainer,
                        labelStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tags will be regenerated when you save',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final editedText = _textController.text.trim();
                    if (editedText.isNotEmpty && editedText != note.content) {
                      setState(() => _isGeneratingTags = true);
                      Navigator.pop(context);

                      // Generate tags using Gemini for the updated content
                      final tags = await _tagGenerator.generateTags(editedText);

                      // Create a new note with the same ID but updated content and tags
                      final updatedNote = Note(
                        id: note.id,
                        content: editedText,
                        createdAt: note.createdAt,
                        tags: tags,
                      );

                      // Update the note in the database
                      if (note.id != null) {
                        await _databaseService.updateNote(updatedNote);
                        await _loadNotes();
                      }

                      setState(() => _isGeneratingTags = false);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Notes'),
              actions: [
                if (_notes.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: 'Delete All Notes',
                    onPressed: _showDeleteAllConfirmation,
                  ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () async{
                   await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                    // Reload notes after returning from settings
                    await _initServices();
                  },
                ),
              ],
            ),
            body: _hasGeminiApiKey
                ? _notes.isEmpty
                    ? const Center(
                        child: Text(
                            'No notes yet. Tap the microphone to create one.'),
                      )
                    : ListView.builder(
                        itemCount: _notes.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          return Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(note.content),
                                  subtitle: Text(
                                    DateFormat('MMM d, y HH:mm')
                                        .format(note.createdAt),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _editNote(note),
                                        tooltip: 'Edit Note',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => _deleteNote(note),
                                        tooltip: 'Delete Note',
                                      ),
                                    ],
                                  ),
                                ),
                                if (note.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    child: Wrap(
                                      spacing: 8,
                                      children: note.tags.map((tag) {
                                        return Chip(
                                          label: Text(tag),
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ): const Center(
                    child: Text(
                        'Please set up your Gemini API key in the Settings.'),
                  ),
            floatingActionButton: 
            _hasGeminiApiKey
            ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'btn_text',
                  onPressed: _openTextNoteDialog,
                  tooltip: 'Add Text Note',
                  child: const Icon(Icons.edit),
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    FloatingActionButton(
                      heroTag: 'btn_voice',
                      onPressed: _startListening,
                      tooltip: 'Record Voice Note',
                      child: Icon(
                        _speechService.isListening ? Icons.mic : Icons.mic_none,
                        color: _speechService.isListening ? Colors.red : null,
                      ),
                    ),
                    if (_speechService.isListening)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ): null,
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.notes), label: 'Notes'),
              ],
                        selectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).indicatorColor
              : Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).disabledColor
              : Theme.of(context).unselectedWidgetColor,

              currentIndex: 1,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()));
                }
              },
            ),
          ),
          // Loading overlay when generating tags
          if (_isGeneratingTags)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          'Generating tags with Gemini AI...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a few seconds',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _localeSubscription?.cancel();
    _speechService.dispose();
    super.dispose();
  }
}
