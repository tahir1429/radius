var config = {};
// ENVIOURMENT
config.env  = { production : true }
// BASE URL
config.url  = { LIVE: 'http://134.209.153.200', TEST: 'http://localhost:4200'}
// HOST
config.host = { LIVE: '127.0.0.1', TEST: '127.0.0.1'}
// PORT
config.port = { LIVE: 8080, TEST: 8080}
// MONGO URL
if( config.env.production ){
    config.MONGO_URI = 'mongodb://radiususer:Radius1429@127.0.0.1:27017/radius?authMechanism=DEFAULT&authSource=admin';
}else{
    config.MONGO_URI = 'mongodb://'+config.host.TEST+':27017/radius';
}
// SERVER TOKEN KEY
config.SERVER_TOKEN_KEY = '12345678%#@)&fr';

// mongodb://radiususer:radius%401429@134.209.153.200:27017/?authMechanism=DEFAULT
// Export Configuration
module.exports = config;


// db.settings.insert({
//     "type": "settings",
//     "setting": {
//       "radius": 4000,
//       "smtpEmail": "radius.app11@gmail.com",
//       "smtpPass": "dmibqtlomveggsgb"
//     }
// });