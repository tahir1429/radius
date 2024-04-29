import 'package:flutter/cupertino.dart';
import 'package:radius_app/services/storageManager.dart';

// class Chat {
//   String? _id;
//   List? messages;
//   List? members;
// }

class ChatManager with ChangeNotifier{
  List _chats = <dynamic>[];
  int _counter= 0;
  String _currentUserId = '';
  static String CHAT_COUNTER_KEY = 'chatCounter';

  ChatManager(){
    StorageManager.readData( CHAT_COUNTER_KEY ).then(( dynamic value){
      _counter = ( value != null && value !='' ) ? value : 0;
      notifyListeners();
    });
  }

  get chats => _chats;
  get counter => _counter;

  set currentUserId ( String uid) => _currentUserId = uid;

  setChats( dynamic data ){
    _chats = data;
    setUnreadCounter();
  }

  removeChat( String chatId ){
    for (var index = 0; index < _chats.length; index++) {
      if ( _chats[index]['_id'] == chatId ) {
        _chats.removeAt(index);
        setUnreadCounter();
      }
    }
  }

  setUnreadCounter(){
    if( chats.isEmpty ){
      _counter = 0;
      StorageManager.saveData('chatCounter', _counter );
      notifyListeners();
    }else{
      _counter = 0;
      chats.map( ( e ) {
        int tempCounter = 0;
        final List messages = e['messages'] ?? [];
        for (var i = 0; i < messages.length; i++) {
          final message = messages[i];
          List read = message['readBy'] ?? [];
          if (message['sender'] != _currentUserId && !read.contains( _currentUserId )) {
            tempCounter++;
          }
        }
        e['counter'] = counter;
        _counter = ( tempCounter > 0 ) ? _counter+1 : _counter;
        return e;
      }).toList();
      StorageManager.saveData('chatCounter', _counter );
      notifyListeners();
    }
  }
}