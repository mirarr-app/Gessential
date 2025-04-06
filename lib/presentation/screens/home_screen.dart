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
          title: const Text('Chat'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
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
                        Container(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Using context from ${_contextNotes.length} relevant notes',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: _contextNotes
                                    .expand((note) => note.tags)
                                    .toSet()
                                    .map((tag) => Chip(
                                          label: Text(tag),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, index) {
                            return ChatMessageWidget(
                                message: _chatMessages[index]);
                          },
                        ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Type your message...',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _toggleListening,
                              icon: const Icon(
                                Icons.mic,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _sendMessage,
                              icon: const Icon(Icons.send),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                              ),
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
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.notes), label: 'Notes'),
          ],
          selectedItemColor: Colors.white,
          currentIndex: 0,
          onTap: (index) {
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
