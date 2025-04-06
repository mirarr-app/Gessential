import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import '../../domain/entities/note.dart';

class DatabaseService {
  static const int _kCurrentVersion = 2;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _kCurrentVersion,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add tags column in version 2
      await db.execute(
          'ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT ""');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT ""
      )
    ''');

    // Add index for faster tag searches
    await db.execute('CREATE INDEX idx_notes_tags ON notes(tags)');
  }

  // Add retry mechanism for database operations
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts == _maxRetries) rethrow;
        await Future.delayed(_retryDelay * attempts);
      }
    }
    throw Exception('Operation failed after $_maxRetries attempts');
  }

  Future<Note> createNote(Note note) async {
    final db = await database;
    final id = await db.insert('notes', note.toMap());
    return Note(
      id: id,
      content: note.content,
      createdAt: note.createdAt,
    );
  }

  // Add batch operations support
  Future<void> createNotes(List<Note> notes) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final note in notes) {
        batch.insert('notes', note.toMap());
      }
      await batch.commit();
    });
  }

  Future<List<Note>> getNotes() async {
    return _withRetry(() async {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'notes',
        orderBy: 'created_at DESC',
      );
      return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
    });
  }

  Future<List<Note>> getNotesByTags(List<String> tags) async {
    if (tags.isEmpty) return [];

    print('\n=== Searching notes by tags ===');
    print('Search tags: $tags');

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'created_at DESC',
    );
    print('Total notes in database: ${maps.length}');

    // Helper function to normalize tags for comparison
    String normalizeTag(String tag) {
      // Remove common plural endings and convert to lowercase
      tag = tag.toLowerCase();
      if (tag.endsWith('s')) tag = tag.substring(0, tag.length - 1);
      if (tag.endsWith('es')) tag = tag.substring(0, tag.length - 2);
      if (tag.endsWith('ies')) tag = tag.substring(0, tag.length - 3) + 'y';
      return tag;
    }

    // Normalize search tags
    final normalizedSearchTags = tags.map(normalizeTag).toList();
    print('Normalized search tags: $normalizedSearchTags');

    // Filter notes that have at least one matching tag
    final notes = maps.map((map) => Note.fromMap(map)).where((note) {
      // Normalize note tags
      final normalizedNoteTags = note.tags.map(normalizeTag).toList();
      print('Note tags: ${note.tags} -> Normalized: $normalizedNoteTags');

      final hasMatchingTag = normalizedNoteTags.any((noteTag) {
        return normalizedSearchTags.any((searchTag) {
          // Check if tags share a common root (one contains the other)
          final matches =
              noteTag.contains(searchTag) || searchTag.contains(noteTag);
          if (matches) {
            print('Match found: $noteTag matches with $searchTag');
          }
          return matches;
        });
      });

      if (hasMatchingTag) {
        print('Found matching note:');
        print('- Content: ${note.content}');
        print('- Tags: ${note.tags}');
      }
      return hasMatchingTag;
    }).toList();

    print('Found ${notes.length} matching notes');
    print('=== Note search complete ===\n');
    return notes;
  }

  Future<void> updateNote(Note note) async {
    if (note.id == null) return;

    final db = await database;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAllNotes() async {
    final db = await database;
    await db.delete('notes');
  }

  // Add cleanup method
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
