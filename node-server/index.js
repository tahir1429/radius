const http     = require('http');
const express  = require("express");
var cors       = require('cors');
const db       = require('./database/connection');
const userRoute= require('./routes/users.router');
const settingRoute= require('./routes/setting.router');
const mongoose = require("mongoose");
const USER     = require("./models/users");
const upload   = require("./middleware/upload");
const { deleteUserAccount, deleteChatAttachments, reportStory, reportUser } = require("./helper/functions");

// Connect Database
db.connect();

// Setup Firebase Admin SDK
var admin = require("firebase-admin");
var serviceAccount = require("./radius-7424e-firebase-adminsdk-i18nj-5a0273475e.json");
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://radius-7424e-default-rtdb.firebaseio.com"
});

// Setup App
const app = express();
var corsOptions = { origin: '*' };
app.use(cors(corsOptions));
app.use(express.json({ limit: "50mb" }));
app.use(express.urlencoded({extended: true}));
app.use('/uploads', express.static(__dirname + '/uploads'));
// Define Routes
app.use( '/user', userRoute );
app.use( '/settings', settingRoute );

// Notification Settings
const notification_options = {
  priority: "normal",
  timeToLive: 60 * 60 * 24,
  contentAvailable : true,
  dryRun : false,
};

app.post( '/send-notification', ( req, res ) => {
  try {
    const body = req.body;
    const message = {
      "notification": {
        "title": body.title,
        "body": body.message,
        "sound": 'default',
      },
      "data": {
        "title" : body.title,
        "message" : body.message
      },
    };
    console.log( 'Sending SMS' );
    const  registrationToken = body.token;
    admin.messaging().sendToDevice( registrationToken, message, notification_options )
    .then( response => {
      for (let index = 0; index < response.results.length; index++) {
        const output = response.results[index];
        if( output?.error ){
          console.log(output?.error.message);
        }else if(  output?.messageId ){
          console.log('Notification sent successfully with msgId: '+output?.messageId );
        }
      }
      return res.status(200).send("Notification sent successfully");
    })
    .catch( error => {
      console.log(error.message);
      return res.status(401).send(error.message)
    });
  } catch (error) {
    console.log( error.message );
    return res.status(500).send(error.message)
  }
});

app.post( '/reset-password', ( req, res ) => {
  try {
    const uid = req.body.uid;
    const pass= req.body.pass;
    // Update password
    admin.auth().updateUser( uid, {
      password : pass
    })
    .then( ( data ) => {
      return res.status( 200 ).json({ status : true, msg : "updated successfully"});
    })
    .catch( ( error ) => {
      return res.status( 401 ).json({ status : false, msg : error.message });
    });
  } catch (error) {
    return res.status( 500 ).json({ status : false, msg : error.message });
  }
});

// UPLOAD IMAGE
app.post( '/upload-image', upload.single('image'), ( req, res ) => {
  try {
    if( req?.file ){
      return res.status(200).json( { status : true, file :  req.file.path } );
    }else{
      return res.status(401).json( { status : false, message :  'File not uploaded' } );
    }
  } catch (error) {
    return res.status( 500 ).json({ status : false, msg : error.message });
  }
});

app.delete( '/remove-image', ( req, res ) => {
  //an arry of image urls will be called here
  const images = req.body.images;
  images.forEach(img => {
    const fileRef = firebase.storage().refFromURL(img);
    // Delete the file
    fileRef.delete()
      .then(() => {
        console.log('File deleted successfully');
      })
      .catch((error) => {
        console.error('Error deleting file:', error);
      });
      })
      return res.status(200).send("File deleted");
});


// This should be the last route else any after it won't work
app.use("*", (req, res) => {
    res.status(404).json({
      success: "false",
      message: "Page not found",
      error: {
        statusCode: 404,
        message: "You reached a route that is not defined on this server",
      },
    });
});

// function sendNotification(){
//     const registrationToken = 'dUp_-oI-vUlmr3fJGF-K4n:APA91bGR73T29jd2fI05lpp-dng0kT6CKXqCEUl_rSm8oxOO2yivLZjmd0A5mFhlCh00HRIlIaU3NI1hJlD-jUdOLZ5ksiRivBx_Vcuj421XGsu5u1ugvyIhWhWxEbiTTbXlPNwsIi9X';
//     const regToken = 'ftAfWCqtQqCwo7JOwnih_E:APA91bFh14RiEt1vACmzRnUDLOH5Dzd3CNlSjn2vzhEglyWJ_Rh9RnFAs5KvGCcDNuWaF_4yiAKDqf9QaeC1fhQ9nmBEpVWc6LvyXM2uQu02ut_B4DXt0jguVtp4FRUJeLrO5EpIAZrj';
//     const message = {
//       "notification": {
//         "title": 'TEST',
//         "body": 'REVIEW',
//         "sound": 'default',
//       },
//       "data": {
//         "title" : 'TEST',
//         "message" : 'REVIEW'
//       },
//     };     
//     admin.messaging().sendToDevice( [registrationToken], message, notification_options )
//         .then( response => {
//           for (let index = 0; index < response.results.length; index++) {
//             const output = response.results[index];
//             if( output?.error ){
//               console.log(output?.error.message);
//             }else if(  output?.messageId ){
//               console.log('Notification sent successfully with msgId: '+output?.messageId );
//             }
//           }
//         })
//         .catch( error => {
//           console.log(error.message);
//         });
// }
// sendNotification();

var port = process.env.PORT || 8080;
const server = http.createServer( app ).listen( port );

// Socket Layer over Http Server
const io = require('socket.io')( server, {
  'pingInterval': 1000, 
  'pingTimeout': 59000,
  cors: {
      origin: '*',
  }   
});

global.active_users = {};
global.disconnected_users = {};

const CHAT = require('./models/chat');

// On every Client Connection
io.on('connection', (socket) => {
  console.log( 'User connected with socket-id: '+socket.id );

  socket.on("userId", ( uid ) => {
    active_users[uid] = socket.id;
    delete disconnected_users[uid];
  });

  socket.on("get-all-chats", async ( data, callback ) => {
    try {
      let withoutCount = data?.withoutCount || false;
      const chats = await CHAT.find({
        members : {
          $in : [data.self]
        }
      });
      if( withoutCount ){
        // get-all-chats
        let otherUserIds = [];
        if( chats.length > 0 ){
          for (let index = 0; index < chats.length; index++) {
            const chat = chats[index];
            let ids = chats[index].members.filter( ( value ) =>  value != data.self );
            otherUserIds = otherUserIds.concat( ids );
          }
        }
        let users = await USER.find( { _id : { $in : otherUserIds } }, { stories : 1, username : 1, avatar : 1 } );
        for (let index = 0; index < users.length; index++) {
          users[index]['stories'] = await verifyStoryExpiration( users[index]['_id'], users[index]['stories']);
        }
        callback({ status: true, chats : chats, users : users });
      }else{
        callback({ status: true, chats : chats });
      }
    } catch (error) {
      console.log( error );
      callback({ status: false, error : error.message });
    }
  }); 

  socket.on("get-single-chat", async ( data, callback ) => {
    try{
      const chat = await CHAT.findOne({
        members : {
          $all : data.members
        }
      });
      // IF CHAT EXIST RETURN
      if( chat ){
        callback({ status: true, chat : chat });
      }
      // IF CHAT NOT-EXIST CREATE NEW & RETURN
      else{
        // EMIT RESPONSE TO ON_CREATE_CHAT TO OTHER MEMBER
        const chat = await CHAT.create( data );
        for (let index = 0; index < chat.members.length; index++) {
          const memberId = chat.members[index];
          if( active_users[memberId] ){
            console.log('send-chat-created');
            socket.to(active_users[memberId]).emit( 'chat-created', { chat : chat } );
          }
        }
        callback({ status: true, chat : chat });
      }
    }catch( e ){
      callback({ status: false, error : e.message });
    }
  });
   
  socket.on("remove-chat", async ( data, callback ) => {
    try {
      const chatId = new mongoose.Types.ObjectId( data.chatId );
      // GET ALL CHATS FOR SPECIFIC USER
      const chat = await CHAT.findById( chatId );
      if( chat ){
        await CHAT.deleteOne({
          _id : chatId
        });
        for (let index = 0; index < chat.members.length; index++) {
          const memberId = chat.members[index];
          if( active_users[memberId] ){
            console.log('send-chat-deleted');
            socket.to(active_users[memberId]).emit( 'chat-deleted', { chatId : chat._id } );
          }
        }
        callback( { status : true, chatId : chatId } );
      }else{
        callback( { status : false, error : 'Chat not found' } );
      }
    } catch (error) {
      console.log('Removing Chats');
      callback( { status : false, error : error.message } );
    }
  });

  socket.on("mark-as-read", async ( data ) => {
    try {
      const chatId = new mongoose.Types.ObjectId( data.chatId );
      const uid    = data.uid; 
      const chat  = await CHAT.findOneAndUpdate(
        { _id : chatId },
        { $addToSet : { 'messages.$[].readBy' : uid } },
        { new: true }
      );
      if( chat ){
        for (let index = 0; index < chat.members.length; index++) {
          const memberId = chat.members[index];
          if( active_users[memberId] && memberId != uid){
              socket.to( active_users[memberId] ).emit( "seen-msg", { chat : chat, readBy : uid } );
          }
        }
      }
    } catch (error) {
      console.log('READ CHAT');
      console.log( error.message );
    }
  });

  socket.on("send-message", async ( data, callback ) => {
    try {
      const chatId = data.chatId;
      let body   = data.msg;
      body.timestamp = new Date(new Date().toUTCString());
      const chat = await CHAT.findOneAndUpdate(
        { _id: chatId },
        { $push: { messages: body } },
        { new : true }
      );
      const lastMessage = chat.messages[chat.messages.length-1];
      for (let index = 0; index < chat.members.length; index++) {
        const memberId = chat.members[index];
        if( active_users[memberId] && memberId != lastMessage.sender ){
          console.log('send-chat-message');
          socket.to(active_users[memberId]).emit( 'new-message', { chatId : chatId, message : lastMessage } );
        }
      }
      callback({status : true, message : lastMessage });
    } catch (error) {
      callback({status : false, error : error.message });
    }
  });

  socket.on("clear-chats", ( data ) => {
    const uid = data.uid;
    removeAllChats( socket, uid);
  });

  socket.on("block-user", async ( data, callback ) => {
    try {
      let query = { $push : { blockedBy : data.self } };
      // Toggle Block Status
      const output = await USER.updateOne( { _id : data.other },  query );
      // Emit Response to Blocked User
      socket.emit( 'blocked', { byUid : data.self, selfId : data.other } );
      socket.to(active_users[data.other]).emit( 'blocked', { byUid : data.self, selfId : data.other } );
      // Send Response to caller
      callback({ status : true, output : output });
    } catch (error) {
      callback({status : false, message : error.message });
    }
  });

  socket.on("report-user", async ( data, callback ) => {
    try {
      await reportUser( data, callback );
    } catch (error) {
      callback({status : false, message : error.message });
    }
  });

  socket.on("report-story", async ( data, callback ) => {
    try {
      await reportStory( data, callback );
    } catch (error) {
      callback({status : false, message : error.message });
    }
  });

  // Update User [Online-Offline] Status
  socket.on("set-user-status", async ( data ) => {
    await updateUserStatus( data.uid, data.status );
  });

  // Update User Visibility Status
  socket.on("set-user-visibility", async ( data ) => {
    await updateUserVisibility( data.uid, data.status, socket );
  });

  socket.on("deactivate-account", async ( data, callback ) => {
    try {
      await deleteUserAccount( data.uid, data.password, socket, active_users, callback );
    } catch (error) {
      callback({status : false, message : error.message });
    }
  });
  

  // Update User [Online-Offline] Status
  socket.on("custom-disconnect", async ( data ) => {
    delete active_users[ data.uid ];
    updateUserStatus( data.uid, false );
    removeAllChats( socket, data.uid );
    updateFcmToken( data.uid, '' );
  });
   
  // On Browser Close/Force-Close/Ethernet Plug Out/Discounnected
  socket.on("disconnect", () => {
    console.log( 'User disconnected with socket-id: '+socket.id );
    const uid = socket_exist( socket.id );
    if( uid != null ){
      disconnected_users[uid] = { socket : socket, attampt : 0 }
      // updateUserStatus( uid, false );
      // updateFcmToken( uid, '' );
      // removeAllChats( socket, uid );
      // delete active_users[ uid ];
    }
  });
});


 // Function to update user [Online-Offline] Status
async function updateUserStatus( uid, status = false ){
  try {
    let query = { isOnline : status };
    // if( !status ){
    //   query = { isOnline : status, 'tokens.fcm' : '' };
    // }
    // Updated User Status
    await USER.updateOne( { _id : uid }, query );
  } catch (error) {
    console.log( error.message );
  }
}

// Function to update user Visibility Status
async function updateUserVisibility( uid, status = false , socket ){
  try {
    let query = { "settings.visible" : status };
    // Update User Visibility
    await USER.updateOne( { _id : uid }, query );
    if( status == false ){
      removeAllChats( socket, uid );
      updateUserStatus( uid, false );
    }else{
      updateUserStatus( uid, true );
    }
  } catch (error) {
    console.log( error.message );
  }
}

 // Function to update user FCM [Notification] Token
 async function updateFcmToken( uid, token = '' ){
  try {
    let query = { 'tokens.fcm' : '' };
    // Updated Token
    await USER.updateOne( { _id : uid }, query );
  } catch (error) {
    console.log( error.message );
  }
}

async function removeAllChats ( socket, uid ){
  try {
    // GET ALL CHATS FOR SPECIFIC USER
    const chats = await CHAT.find({
      members : {
        $in : [ uid ]
      }
    });
    // REMOVE ALL CHATS FOR SPECIFIC USER
    await CHAT.deleteMany({
      members : uid 
    });
    // NOTIFY OTHER MEMBERS OF CHATS
    for (let index = 0; index < chats.length; index++) {
      const chat = chats[ index ];
      deleteChatAttachments( chat );
      for (let j = 0; j < chat.members.length; j++) {
        const memberId = chat.members[j];
        if( active_users[memberId] && memberId != uid ){
          socket.to(active_users[memberId]).emit( 'chat-deleted', { chatId : chat._id } );
        }
      }
    } 
  } catch (error) {
    console.log( error.message );
  }
}

function socket_exist( sid ){
  let uid = null;
  for (const [key, value] of Object.entries(active_users)) {
      if(value == sid ){
        uid = key;
        break;
      }
  }
  return uid;
}

var minutes = 1, the_interval = minutes * 60 * 1000;
setInterval(function() {
  for (var k in disconnected_users ) {
    if (disconnected_users.hasOwnProperty(k)) {
      if( disconnected_users[k].attampt < 2 ){
        disconnected_users[k].attampt++;
      }else{
        updateUserStatus( k, false );
        //updateFcmToken( k, '' );
        removeAllChats( disconnected_users[k].socket, k );
        delete disconnected_users[k];
      }
    }
  }
}, the_interval);


var the_active_interval = 3 * 60 * 1000;
setInterval( async function() {
  if( Object.keys(active_users).length === 0  ){
    await USER.updateMany( {}, { isOnline : false } );
    await CHAT.deleteMany();
  }
}, the_active_interval);


/****************************************************************************
 * FUNCTION : VERIFY STORY EXPIRATION
 * This function verify stories if expired or not. 
 * It deletes the expired one and return Array of not-expired stories.
 * @param {*} userId USER ID
 * @param {*} stories Story Array
 * @returns Valid (Not Expired) Story Array
 ****************************************************************************/
async function verifyStoryExpiration( userId, stories ) {
  if( stories.length > 0 ){
      let validStories = [];
      let deleteStories = [];
      for (let index = 0; index < stories.length; index++) {
          const story = stories[index];
          let dateNow = new Date(Date.now());
          let dateStory = new Date( story.uploadedOn );
          var ms = Math.abs(dateNow.getTime()-dateStory.getTime());
          let timeDiff =  {
              days: Math.round((ms/(60*1000*60))/24),
              hours: Math.floor(ms/(60*1000*60)%24),
              minutes: Math.floor((ms/(60*1000))%60),
              seconds: Math.floor(((ms/1000)%(60*60))%60)
          };
          if( parseInt( timeDiff.days ) == 0 && parseInt( timeDiff.hours ) < 12 ){
              validStories.push( story );
          }else{
              deleteStories.push( story);
          }
      }
      return validStories;
  }else{
      return [];
  }
}


/*************************************
 * EVENTS
 *************************************
 * on-create-chat
 * on-new-msg
 * on-delete-chat
 *************************************/