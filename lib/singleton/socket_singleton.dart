import 'package:flutter/cupertino.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

final protocol   = dotenv.env['SERVER_PROTOCOL'];
final serverPath = dotenv.env['SERVER_URL'];

class SocketSingleton{
  List chats = [].obs;

  final Socket _socket = io(
    ( '$protocol://$serverPath' ).toString(),
    OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableForceNewConnection()
        .setTimeout(5000)
        .setReconnectionDelay(10000)
        .enableReconnection()
        .build(),
  );

  // A static private instance to access _instance from inside class only
  static final SocketSingleton _instance = SocketSingleton._internal();
  // An internal private constructor to access it for only once for static instance of class.
  SocketSingleton._internal();

  // Factry constructor to retutn same static instance everytime you create any object.
  factory SocketSingleton() {
    return _instance;
  }

  Socket get socket => _socket;

  void init( String uid ) {
    debugPrint('socket init status : ${socket.connected}');
    if (socket.connected == false) {
      socket.connect();
      socket.onConnect((data) {
        socket.emitWithAck('userId', uid, ack: (data) {
          debugPrint('ack $data') ;
        });
        debugPrint( 'socket connected with sid : ${socket.id}');
      });
      socket.onError((error) {
        debugPrint( error.toString() );
      });
      socket.on('unauthorized', (dynamic data) {
        debugPrint('Unauthorized');
      });
      socket.onReconnecting((data){
        debugPrint('socket reconnecting');
      });
      socket.onReconnect((data){
        debugPrint('socket reconnected');
      });
      socket.onDisconnect((dynamic data) {
        debugPrint('socket disconnected');
      });
    } else {
      debugPrint('socket already connected with sid : ${socket.id}');
    }
  }

  void listenToEvent(String eventName, Function(dynamic) callback) {
    socket.on(eventName, callback);
  }

  void emitEvent(String eventName, dynamic data) {
    socket.emit(eventName, data);
  }

  void listenToCounterEvent( Function(dynamic) callback) {
    socket.on('new-message', callback);
    socket.on('chat-deleted', callback);
    socket.on('chat-created', callback);
    socket.on('blocked', callback);
  }
}