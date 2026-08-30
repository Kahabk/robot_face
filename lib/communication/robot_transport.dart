/// Abstract transport interface for robot communication
abstract class RobotTransport {
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> send(Map<String, dynamic> data);
  Stream<Map<String, dynamic>> get messages;
}
