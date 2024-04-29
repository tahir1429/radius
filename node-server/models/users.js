const mongoose = require("mongoose");

const pointSchema = new mongoose.Schema({
    type: {
      type: String,
      enum: ['Point'],
      required: true
    },
    coordinates: {
      type: [Number],
      required: true
    }
});

function currentDateTime () { return new Date(new Date().toUTCString()) };

const storySchema = new mongoose.Schema({ 
  url  : { type : String, required : true },
  caption  : { type : String, default : '' },
  type : { type : String, required : true, enum : ['image', 'video'] },
  uploadedOn : { type: Date, default : currentDateTime() }
});

const userSchema = new mongoose.Schema({
    fname    : { type: String, required: true },
    lname    : { type: String, required: true },
    email    : { type: String, required: true, unique : true },
    username : { type: String, default: null },
    password : { type: String, required: true, },
    phone    : { type: String, default: null },
    dob      : { type: String, default: null },
    tokens   : {
        fcm : { type: String, default: null }
    },
    avatar : { 
        type : { type : String, default : '' },
        url  : { type : String, default : '' }
    },
    status : { 
        option : { type : String, default : 'status_one' },
        text   : { type : String, default : '' }
    },
    stories   : [ storySchema ],
    location  : { type : pointSchema, index: '2dsphere' },
    blockedBy : [ String ],
    isOnline  : { type: Boolean, default: true },
    settings  : {
      visible : { type : Boolean, default : true }
    }
},
  { timestamps: true },
  { collection: 'users' }
);

module.exports = mongoose.model("users", userSchema);