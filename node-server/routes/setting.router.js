const express  = require("express");
const router   = express.Router();
const SETTINGS = require("../models/settings");

// Get Settings
router.post("/get", async (req, res) => {
    try {
        // Get Settings
        const settings = await SETTINGS.findOne( { type : req.body.type } );
        // Send Response
        return res.status( 200 ).json( { settings : settings } );
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
});


module.exports = router;