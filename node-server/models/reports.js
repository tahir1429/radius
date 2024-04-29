const mongoose = require("mongoose");

const reportSchema = new mongoose.Schema({
    type    : { type: String, required: true, enum: ['user', 'story']},
    reported_by : { type: String, required: true },
    reported_to : { type: String, required: true },
    reason : { type: String, default: '' },
    storyId : { type: String, default: '' },
}, { timestamps: true }, { collection: 'reports' }
);

module.exports = mongoose.model("reports", reportSchema);