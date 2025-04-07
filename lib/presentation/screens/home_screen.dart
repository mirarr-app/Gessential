import 'package:Gessential/core/config/env_config.dart';
import 'package:flutter/material.dart';
import 'package:Gessential/presentation/screens/notes_screen.dart';
import '../../core/services/speech_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/tag_generator_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/repositories/gemini_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/chat_repository.dart';
import '../widgets/chat_message_widget.dart';
import '../screens/settings_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _chatMessages = [];
  final SpeechService _speechService = SpeechService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final TagGeneratorService _tagGenerator = TagGeneratorService.instance;
  final SettingsService _settingsService = SettingsService.instance;
  ChatRepository? _chatRepository;
  bool _isLoading = false;
  bool _isInitialized = false;
  String _selectedLocaleId = SpeechService.englishLocaleId;

  List<Note> _contextNotes = [];

  StreamSubscription? _localeSubscription;

  bool _hasGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    _initServices();

    _selectedLocaleId = _settingsService.selectedLocaleId;

    _localeSubscription = _settingsService.localeStream.listen((localeId) {
      if (mounted && _selectedLocaleId != localeId) {
        setState(() {
          _selectedLocaleId = localeId;
        });
      }
    });
  }

  Future<void> _initServices() async {
    // Check API key first
    _hasGeminiApiKey = await EnvConfig.hasValidGeminiApiKey();

    if (_hasGeminiApiKey) {
      final chatRepo = GeminiRepository();
      await chatRepo.initialize();
      final speechInitialized = await _speechService.initialize();

      if (mounted) {
        setState(() {
          _chatRepository = chatRepo;
          _isInitialized = speechInitialized;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isInitialized = true; // We're initialized, just without an API key
        });
      }
    }
  }

  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleListening() async {
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

    if (_speechService.isListening) {
      await _speechService.stopListening();
      if (mounted) setState(() {}); // Update UI to reflect listening state
    } else {
      await _speechService.startListening(
        (recognizedWords) {
          if (!mounted) return;
          setState(() {
            _messageController.text = recognizedWords;
          });
          _sendMessage();
        },
        localeId: _selectedLocaleId,
      );
      if (mounted) setState(() {}); // Update UI to reflect listening state
    }
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;
    if (_messageController.text.trim().isEmpty || _chatRepository == null) {
      return;
    }

    final userMessage = _messageController.text;

    setState(() {
      _chatMessages.add(ChatMessage(role: 'user', content: userMessage));
      _isLoading = true;
    });
    _messageController.clear();

    try {
      // Generate tags for the user's message
      final messageTags = await _tagGenerator.generateTags(userMessage);

      if (!mounted) return;

      // Find relevant notes based on tags
      _contextNotes = await _databaseService.getNotesByTags(messageTags);

      if (!mounted) return;

      // Create context from relevant notes
      String context = '';
      String currentDateTime = _getCurrentDateTime();
      if (_contextNotes.isNotEmpty) {
        context =
            'Current date and time is $currentDateTime ,Here are some relevant notes that might help answer the question:\n\n' +
                _contextNotes.map((note) => '- ${note.content}').join('\n\n') +
                '\n\nBased on these notes, please answer the following question: ';
      } 

      // Send message with context
      final response = await _chatRepository!.sendMessage(context + userMessage);

      if (!mounted) return;

      if (response.contains('Error communicating')) {
        throw Exception(response);
      }

      setState(() {
        _chatMessages.add(ChatMessage(role: 'assistant', content: response));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chatMessages.add(ChatMessage(
            role: 'assistant',
            content:
                'Sorry, I encountered an error: ${e.toString()}. Please try again.'));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text('Chat', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, size: 24),
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
                // Re-initialize services when returning from settings
                _initServices();
              },
            ),
          ],
        ),
        body: !_isInitialized && _chatMessages.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _hasGeminiApiKey
                ? Column(
                    children: [
                      if (_contextNotes.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, 
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Context from ${_contextNotes.length} notes',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _contextNotes
                                      .expand((note) => note.tags)
                                      .toSet()
                                      .map((tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.secondaryContainer,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              tag,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ChatMessageWidget(message: _chatMessages[index]),
                            );
                          },
                        ),
                      ),
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(
                                    color: Theme.of(context).hintColor,
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FloatingActionButton(
                              heroTag: 'mic',
                              mini: true,
                              onPressed: _toggleListening,
                              child: const Icon(Icons.mic, size: 20),
                            ),
                            const SizedBox(width: 8),
                            FloatingActionButton(
                              heroTag: 'send',
                              mini: true,
                              onPressed: _sendMessage,
                              child: const Icon(Icons.send, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text(
                        'Please set up your Gemini API key in the Settings.'),
                  ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.notes_outlined),
              selectedIcon: Icon(Icons.notes),
              label: 'Notes',
            ),
          ],
          onDestinationSelected: (index) {
            if (index == 1) {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => const NotesScreen()));
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _localeSubscription?.cancel();
    super.dispose();
  }
}
