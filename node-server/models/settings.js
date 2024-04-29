const mongoose = require("mongoose");

const settingSchema = new mongoose.Schema({
    type    : { type: String, required: true, unique : true },
    setting : { type: Object, required: true, default : {} },
});

module.exports = mongoose.model("settings", settingSchema);