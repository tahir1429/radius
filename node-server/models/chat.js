const mongoose = require("mongoose");

const chatSchema = new mongoose.Schema({
  createdBy   : { type: String, required: true },
  members     : [ String ],
  memberInfo  : [ Object ],
  messages    : [
    { 
        sender : { type: String, required: true },
        text   : { type: String, default: null },
        attachment : { type : Object, default: null },
        flagged : [],
        readBy  : [],
        timestamp : { type: Date, default : new Date(Date.now())}
    }
  ],
},
  { timestamps: true },
  { collection: 'chats' }
);

module.exports = mongoose.model("chats", chatSchema);