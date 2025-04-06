abstract class ChatRepository {
  Future<void> initialize();
  Future<String> sendMessage(String message);
}
