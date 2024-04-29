// Libraries
const express  = require("express");
const router   = express.Router();
const bcrypt   = require("bcryptjs");
const jwt      = require("jsonwebtoken");
const fs       = require('fs');
// Middleware
const auth     = require("../middleware/auth");
const upload   = require("../middleware/upload");
// Models
const USER     = require("../models/users");
// Configuration
const config   = require("../config");


/*****************************************************
 * Register User (Step 1)
 * This endpoint register user on application
 *****************************************************/
router.post("/register", upload.single('image'), async (req, res) => {
    try {
        // Get Request Parameters
        let body = {
            fname: req.body.fname,
            lname: req.body.lname,
            email: req.body.email,
            phone: req.body.phone,
            dob  : req.body.dob,
            isOnline : false,
            password: req.body.password,
        };
        // Hash (Encrypt) Password using bcrypt with 10 rounds 
        body.password = await bcrypt.hash( body.password, 10 );
        // Create New User
        var user = await USER.create( body );
        // Generate JWT Token for 24 hours
        const token = jwt.sign(
            { uid: user._id, username : user.email },
            config.SERVER_TOKEN_KEY,
            { expiresIn: "24h"}
        );
        // Send Response
        return res.status( 200 ).json( { user : user, token : token } );
    } catch (error) {
        // Send Error
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Complete User Registration (Step 2)
 * This endpoint completes user registeration after
 * step-1 with profile-image & username
 *****************************************************/
router.post("/complete-registration", upload.single('image'), async (req, res) => {
    try {
        // Get Request Body (Username & Image)
        let body = {
            username: req.body.username,
            avatar : { type : req.body.avatar_type, url : req.body.avatar_url },
        };
        // Check if user has uploaded any image
        if( body.avatar.type == 'network' && req?.file ){
            // Set Url to uploaded file path
            body.avatar.url = req.file.path;
        }
        // Update User Information
        var user = await USER.findOneAndUpdate(
            { _id : req.body.uid },
            body,
            { new : true }
        );
        // Generate JWT Token for 24 hours
        const token = jwt.sign(
            { uid: user._id, username : user.username },
            config.SERVER_TOKEN_KEY,
            { expiresIn: "24h"}
        );
        // Send Response
        return res.status( 200 ).json( { user : user, token : token } );
    } catch (error) {
        // Send Error
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Login User
 * This endpoint verify user credentials using email
 * and passowrd
 *****************************************************/
router.post("/login", async (req, res) => {
    try {
        // Find user by emial
        var user = await USER.findOne( { email : req.body.email } );
        // Verify Password
        if (user && (await bcrypt.compare( req.body.pass, user.password ))) {
            // Create JWT token
            const token = jwt.sign(
                { uid: user._id, username : user.username },
                config.SERVER_TOKEN_KEY,
                { expiresIn: "24h"}
            );
            // Send Response
            return res.status(200).json({ user : user, token : token });
        }else{
            // Send Error (Password is incorrect)
            return res.status(401).json({ message : 'Invalid Credentials' });
        }
    } catch (error) {
        // Send Error (Password is incorrect)
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Check Duplication
 * This endpoints check while registration either email
 * or username is already taken or not
 *****************************************************/
router.post("/check-duplicate", async (req, res) => {
    try {
        // Get Request body
        const body = req.body;
        // Prepare Empty query
        let query  = {};
        // If request type is to check username
        if( body.type == 'username' ){
            // Prepare query for username
            query = { 'username' : body.username };
        }
        // If request type is to check email
        else if( body.type == 'email' ){
            // Prepare query for email
            query = { 'email' : body.email };
        }
        // If request type is not added
        else{
            // Retuen invalid request
            return res.status(401).json({ message : 'Invalid Access' });
        }
        // Check If single record exist against prepared query
        const response = await USER.findOne( query );
        if( response ){
            // Return response (FOUND)
            return res.status(200).json({ exist : true });
        }else{
            // Return response (NOT-FOUND)
            return res.status(200).json({ exist : false });
        }
    } catch (error) {
        // Return error
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Find User By Email
 * This endpoints find user by email to verify user login
 * when application is initialized
 *****************************************************/
router.post("/find-by-email", async (req, res) => {
    try {
        // Get Request body
        const body = req.body;
        // Prepare query
        let query  = { email : body.email };
        // Find User
        const response = await USER.findOne( query );
        if( response ){
            // User Found
            return res.status(200).json({ user : response });
        }else{
            // User Not Found
            return res.status(401).json({ message : 'User not exist' });
        }
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Find User By Email or ID
 * This endpoints find user by email or id 
 *****************************************************/
router.post("/find-single-user", async (req, res) => {
    try {
        // Get Request body
        const body = req.body;
        // Parpare Empty query
        let query = {};
        // Check if request is with email
        if( body.email != '' ){
            // Prepare query with email
            query = { email : body.email };
        }
        // Check if reqiest is with user id
        else if( body.id != '' ){
            // Preapare query with id
            query = { _id : body.id };
        }
        // If body is empty
        else{
            // Return invalid params error
            return res.status(401).json({ message : 'Invalid parameters passed' });
        }
        // Find User
        const response = await USER.findOne( query );
        if( response ){
            // User Found
            return res.status(200).json({ user : response });
        }else{
            // User not Found
            return res.status(401).json({ message : 'User not found' });
        }
    } catch (error) {
        // Return Error
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Update User Avatar
 * This endpoints update user profile picture
 *****************************************************/
router.post("/update-avatar", upload.single('image'), async (req, res) => {
    try {
        // Get Request Body
        let data  = req.body;
        // Prepare body with type & url of image
        let body  = { type : data.type, url : data.url }; 
        // Check if new image is uploaded
        if( data.type == 'network' && req?.file ){
            // Update image path
            body.url = req.file.path;
        }
        // Find User if exist
        const find = await USER.findById( data.uid, { avatar : 1 } );
        // Remove Previous Image if uploaded to server
        if( find && find.avatar.type == 'network' && fs.existsSync( find.avatar.url ) ){
            fs.unlinkSync( find.avatar.url );
        }
        // Updated User
        const user = await USER.findOneAndUpdate( { _id : data.uid }, { avatar : body } , { new : true } );
        // Send Response
        return res.status( 200 ).json( { user : user } );
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Update User BIO
 * This endpoints update user bio/status
 *****************************************************/
router.post("/update-bio", async (req, res) => {
    try {
        // Get request body
        let data  = req.body;
        // Parepare body with status option & status text
        let body  = { option : data.option, text : data.text }; 
        // Updated User
        const user = await USER.findOneAndUpdate( { _id : data.uid }, { status : body } , { new : true } );
        // Send updated user data
        return res.status( 200 ).json( { user : user } );
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Update User Availability [Online-Offline]
 * This endpoints update user availability
 *****************************************************/
router.post("/update-availability", async (req, res) => {
    try {
        // Get request data & check if user is online or offline
        let isOnline  = (req.body.isOnline == 'true') ? true : false;
        // Prepare body
        let query = { isOnline : isOnline };
        // Updated User
        const user = await USER.updateOne( { _id : req.body.uid }, query );
        // Send Empty Response
        return res.status( 200 ).json(null);
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Update User FCM (Push Notification) Token
 * This endpoints update user fcm token
 *****************************************************/
router.post("/update-fcm-token", async (req, res) => {
    try {
        // Get token from request
        let token  = req.body.token;
        // Prepare query
        let query = { 'tokens.fcm' : token };
        // Updated User
        const user = await USER.findOneAndUpdate( { _id : req.body.uid }, query , { new : true } );
        // Send updated user in response
        return res.status( 200 ).json({ user : user });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Update User Current Location
 * This endpoints update user location
 *****************************************************/
router.post("/update-location", async (req, res) => {
    try {
        // Get request data (lat & lng) & parse into float values
        let location  = {
            type : "Point",
            coordinates : [ parseFloat(req.body.longitude), parseFloat( req.body.latitude ) ]
        };
        // Prepare query
        let query = { location : location };
        // Updated User
        const user = await USER.findOneAndUpdate( { _id : req.body.uid }, query , { new : true } );
        // Send updated user in response
        return res.status( 200 ).json({ user : user });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Get User Blocked List
 * This endpoints returns user blocked list
 *****************************************************/
router.post("/block-list", async (req, res) => {
    try {
        // Get Blocked Users by current user
        const user = await USER.find( { blockedBy : { $in : [ req.body.uid ]  }  } );
        // Send Response (Blocked users list)
        return res.status( 200 ).json({ users : user });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Block / Un-Block User
 * This endpoints block & unblock users
 *****************************************************/
router.post("/toggle-block", async (req, res) => {
    try {
        let query = {};
        // Prepare query if user is blocking or unblocking
        if( req.body.block == 'true' ){
            query = { $push : { blockedBy : req.body.blockBy } };
        }else{
            query = { $pull : { blockedBy : req.body.blockBy } };
        }
        // Toggle Block Status
        const output = await USER.updateOne( { _id : req.body.blockTo },  query );
        // Send Response
        return res.status( 200 ).json({ output : output });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
});

/*****************************************************
 * Update Password
 * This endpoints updates user password
 *****************************************************/
router.post("/update-password", async (req, res) => {
    try {
        // Get password from body & encrypt it
        req.body.password = await bcrypt.hash( req.body.password, 10 );
        // Updated User Password
        const output = await USER.updateOne( { _id : req.body.uid }, { password : req.body.password } );
        // Send Response
        return res.status( 200 ).json({ output : output });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Meters to Radian
 * Formula to convert [Meters] into [Miles] & [Radian]
 *****************************************************/
var metersToRadian = function( meters ){
    var miles = meters * 0.000621371;
    var earthRadiusInMiles = 3959;
    return miles / earthRadiusInMiles;
};

/*****************************************************
 * Find Nearby Users
 * This endpoint find nearby people according to user
 * current lat & lng
 *****************************************************/
router.post("/find-nearby", async (req, res) => {
    try {
        // Get user id
        const uid    = req.body.uid;
        // Get radius
        const radius = parseInt( parseFloat(req.body.radius) * 1000 ) ;
        // Get user current coordinates
        const coordinates = [ parseFloat(req.body.longitude), parseFloat(req.body.latitude) ];
        // Find user who is requesting
        const self = await USER.findOne({ _id : uid }, { blockedBy : 1 } );
        // Get block list of requester to skip user whom he has blocked
        selfBlockList = self.blockedBy || [];
        // Find nearby users
        const users = await USER.find(
            {
                $and : [
                    // If user is online
                    { isOnline : true },
                    // If user is not in requester block list
                    { _id : { $nin : selfBlockList } },
                    // If user is within its radius
                    {
                        location : {
                            $geoWithin : { 
                                $centerSphere : [ coordinates, metersToRadian( radius ) ]
                            }
                        } 
                    }
                ],
            }
        );
        // Send list of users in response
        return res.status( 200 ).json({ users : users });
    } catch (error) {
        console.log( error.message );
        return res.status(401).json({ code : 'SERVER_ERROR', message : error.message });
    }
});

/*****************************************************
 * Create Story
 * This endpoint creates user story
 *****************************************************/
router.post("/create-story", upload.single('file'), async (req, res) => {
    try {
        // Get request data
        const body = req.body;
        // Get current date-time
        const currentDateTime = new Date(new Date().toUTCString());
        // Check if file is uploaded
        if( req?.file ){
            // Prepare query/body
            let story = { 
                url : req.file.path, 
                type : body.type, 
                caption :  body.caption,
                uploadedOn : currentDateTime
            };
            // Create New Story
            const output = await USER.findOneAndUpdate( 
                { _id : body.uid }, 
                { $push : { stories : story } },
                { new : true }
            );
            // Return new story
            return res.status( 200 ).json({ story : output.stories[output.stories.length-1] });
        }else{
            return res.status(401).json({ message : 'Error occured while uploading image' });
        }
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Get Story
 * This endpoint returns user stories
 *****************************************************/
router.post("/get-story", upload.single('file'), async (req, res) => {
    try {
        // Get request body
        const body = req.body;
        // Finf user & its stories
        const output = await USER.findOne( 
            { _id : body.uid }, 
            { stories : 1 }
        );
        // Check for expired stories [Delete expired ones]
        const stories = await verifyStoryExpiration( output['_id'], output['stories'] );
        // Return stories which are valid
        return res.status( 200 ).json({ stories : stories });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
}); 

/*****************************************************
 * Delete Story
 * This endpoint delete user story
 *****************************************************/
router.post("/delete-story", async (req, res) => {
    try {
        // Get Request body
        const body = req.body;
        // Pop user story from array by id
        const output = await USER.updateOne( 
            { _id : body.uid }, 
            { $pull: { stories: { _id: body.storyId } } },
        );
        // Remove Previous Image if uploaded to server
        if( fs.existsSync( body.url ) ){
            fs.unlinkSync( body.url );
        }
        // Return success message
        return res.status( 200 ).json({ message : 'Removed successfully' });
    } catch (error) {
        return res.status(401).json({ message : error.message });
    }
});
 
/****************************************************************************
 * FUNCTION : VERIFY STORY EXPIRATION
 * This function verify stories if expired or not. 
 * It deletes the expired one and return Array of not-expired stories.
 * @param {*} userId USER ID
 * @param {*} stories Story Array
 * @returns Valid (Not Expired) Story Array
 ****************************************************************************/
async function verifyStoryExpiration( userId, stories ) {
    // If stories exist
    if( stories.length > 0 ){
        // Store Valid Stories
        let validStories = [];
        // Store Expired Stories
        let deleteStories = [];
        for (let index = 0; index < stories.length; index++) {
            const story = stories[index];
            let dateNow = new Date(Date.now());
            let dateStory = new Date( story.uploadedOn );
            var ms = Math.abs(dateNow.getTime()-dateStory.getTime());
            // Get time diffrence between current & uploaded time
            let timeDiff =  {
                days: Math.round((ms/(60*1000*60))/24),
                hours: Math.floor(ms/(60*1000*60)%24),
                minutes: Math.floor((ms/(60*1000))%60),
                seconds: Math.floor(((ms/1000)%(60*60))%60)
            };
            // If story upload duration is less than 12 hours [VALID]
            if( parseInt( timeDiff.days ) == 0 && parseInt( timeDiff.hours ) < 12 ){
                validStories.push( story );
            }
            // If story upload duration is greater than 12 hours [DELETE]
            else{
                console.log( 'Story Uploaded On', story.uploadedOn );
                console.log( 'Current Time', dateNow );
                console.log( 'Story Deleting At', timeDiff, 'for', userId);
                deleteStories.push( story);
            }
        }
        // [CHECK] - IF EXPIRED STORIES EXIST
        if( deleteStories.length > 0 ){
            // GET ID OF EACH STORY
            let idsToDelete = deleteStories.map( ( item ) => item._id );
            // DELETE STORIES FROM DATABASE
            await USER.updateOne( 
                { _id : userId }, 
                { $pull: { stories: { _id: { $in : idsToDelete } } } },
            );
            // DELETE STORY FILES FROM SERVER
            for (let index = 0; index < deleteStories.length; index++) {
                const item = deleteStories[index];
                if( fs.existsSync( item.url ) ){
                    fs.unlinkSync( item.url );
                }
            }
        }
        // Return valid stories
        return validStories;
    }else{
        return [];
    }
}


// http://thecodebarbarian.com/80-20-guide-to-mongodb-geospatial-queries
// FOR GEO QUERIES

module.exports = router;