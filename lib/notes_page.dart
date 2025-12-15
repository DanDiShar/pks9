import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final Stream<List<Map<String, dynamic>>> _notesStream;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _printDebugInfo();
  }

  void _printDebugInfo() {
    final user = _supabase.auth.currentUser;
    print('DEBUG: Текущий пользователь: ${user?.id}');
    print('DEBUG: Email: ${user?.email}');
  }

  void _initializeStream() {
    try {
      final userId = _supabase.auth.currentUser!.id;
      print('DEBUG: Инициализация потока для user_id: $userId');
      
      _notesStream = _supabase
          .from('notes')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
          
      print('DEBUG: Поток создан успешно');
    } catch (e) {
      print('DEBUG: Ошибка создания потока: $e');
    }
  }

  Future<void> _createNote({
    required String title,
    required String content,
  }) async {
    print('DEBUG: Создание заметки: title=$title, content=$content');
    
    try {
      final userId = _supabase.auth.currentUser!.id;
      print('DEBUG: user_id для вставки: $userId');
      
      final response = await _supabase.from('notes').insert({
        'user_id': userId,
        'title': title,
        'content': content,
      });
      
      print('DEBUG: Ответ от Supabase: $response');
      print('DEBUG: Заметка создана успешно');
      
    } catch (error) {
      print('DEBUG: Ошибка создания заметки: $error');
      _showError('Ошибка создания заметки: $error');
    }
  }

  Future<void> _updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    try {
      print('DEBUG: Обновление заметки $id');
      
      await _supabase.from('notes').update({
        'title': title,
        'content': content,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      
      print('DEBUG: Заметка обновлена успешно');
      
    } catch (error) {
      print('DEBUG: Ошибка обновления заметки: $error');
      _showError('Ошибка обновления заметки: $error');
    }
  }

  Future<void> _deleteNote(String id) async {
    try {
      await _supabase.from('notes').delete().eq('id', id);
      print('DEBUG: Заметка удалена: $id');
    } catch (error) {
      print('DEBUG: Ошибка удаления заметки: $error');
      _showError('Ошибка удаления заметки: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showNoteDialog({
    String? id,
    String initialTitle = '',
    String initialContent = '',
  }) {
    final titleController = TextEditingController(text: initialTitle);
    final contentController = TextEditingController(text: initialContent);
    final isEditing = id != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Редактировать заметку' : 'Новая заметка'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Содержание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                minLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final content = contentController.text.trim();

              if (title.isEmpty) {
                _showError('Введите заголовок');
                return;
              }

              if (isEditing) {
                await _updateNote(
                  id: id!,
                  title: title,
                  content: content,
                );
              } else {
                await _createNote(
                  title: title,
                  content: content,
                );
              }

              if (mounted) Navigator.pop(context);
            },
            child: Text(isEditing ? 'Сохранить' : 'Создать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои заметки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
            },
            tooltip: 'Выйти',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notesStream,
        builder: (context, snapshot) {
          print('DEBUG: StreamBuilder snapshot: ${snapshot.connectionState}');
          
          if (snapshot.hasError) {
            print('DEBUG: Ошибка в потоке: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Ошибка загрузки заметок'),
                  Text('${snapshot.error}'),
                  TextButton(
                    onPressed: _initializeStream,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return const Center(child: Text('Нет подключения к базе'));
            case ConnectionState.waiting:
              return const Center(child: CircularProgressIndicator());
            case ConnectionState.active:
            case ConnectionState.done:
              if (!snapshot.hasData) {
                return const Center(child: Text('Нет данных'));
              }
              
              final notes = snapshot.data!;
              print('DEBUG: Получено заметок: ${notes.length}');
              
              if (notes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.note_add, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Нет заметок'),
                      const SizedBox(height: 8),
                      const Text('Нажмите "+" чтобы создать первую заметку'),
                      TextButton(
                        onPressed: () => _showNoteDialog(),
                        child: const Text('Создать заметку'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        note['title'] ?? 'Без названия',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            note['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(note['updated_at']),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNote(note['id']),
                        tooltip: 'Удалить',
                      ),
                      onTap: () => _showNoteDialog(
                        id: note['id'],
                        initialTitle: note['title'] ?? '',
                        initialContent: note['content'] ?? '',
                      ),
                    ),
                  );
                },
              );
          }
        },
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}