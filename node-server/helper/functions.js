const USER    = require("../models/users");
const CHAT    = require('../models/chat');
const REPORT  = require('../models/reports');
const fs      = require('fs');
const bcrypt  = require("bcryptjs");

/****************************************************************************
 * FUNCTION : DEACTIVATE USER ACCOUNT
 * This function deletes user account completely
 * @param {*} userId USER ID
 ****************************************************************************/
async function deleteUserAccount( userId, password, socket = null, active_users = {}, callback ){
    try {
        console.log('Deleting Account with UID : '+userId);
        const user = await USER.findById( userId );
        if (user && (await bcrypt.compare( password, user.password ))) {
            /***************************************
             * DELETE USER CHATS
            ****************************************/
            // 1. GET ALL CHATS FOR SPECIFIC USER
            const chats = await CHAT.find({members : { $in : [ userId ] }});
            // IF CHATS EXIST
            if( chats.length > 0 ){
                // A. DELETE ALL CHATS
                await CHAT.deleteMany({members : userId});
                // B. NOTIFY OTHER MEMBERS & DELETE CHAT ATTACHMENTS
                for (let index = 0; index < chats.length; index++) {
                    const chat = chats[ index ];
                    // I. DELETE CHAT ATTACHMENTS/MEDIA FORM SERVER
                    deleteChatAttachments( chat );
                    // II. NOTIFY OTHER MEMBERS
                    if( socket != null ){
                        for (let j = 0; j < chat.members.length; j++) {
                            const memberId = chat.members[j];
                            if( active_users[memberId] && memberId != userId ){
                            socket.to(active_users[memberId]).emit( 'chat-deleted', { chatId : chat._id } );
                            }
                        }
                    }
                }
            }
            /***************************************
            * DELETE USER ACCOUNT
            ****************************************/
            // A. DELETE USER
            await USER.deleteOne({ _id : userId });
            // B. Delete User Avatar
            if( user.avatar.type == 'network' && fs.existsSync( user.avatar.url )){
                fs.unlinkSync( user.avatar.url );
            }
            // C. Delete User Story Image
            if( user?.stories && user.stories.length > 0 ){
                for (let index = 0; index < user.stories.length; index++) {
                    const story = user.stories[index];
                    if( fs.existsSync( story.url )){
                        fs.unlinkSync( story.url );
                    }
                }
            }
            callback({status : true, message : 'User Account Deleted' });
        }else{
            callback({status : false, message : 'Invalid Password' });
        }
    } catch (error) {
        console.error( 'DEACTIVATING USER ACCOUNT' );
        console.error( error.message );
        callback({status : false, message : error.message });
    }
}

/****************************************************************************
 * FUNCTION : DELETE CHAT ATTACHMENTS
 * This function deletes chat attachment/media if exist
 * @param {*} chat CHAT OBJECT
 ****************************************************************************/
function deleteChatAttachments( chat ){
    try {
        if( chat?.messages && chat.messages.length > 0 ){
            for (let j = 0; j < chat.messages.length; j++) {
                const message = chat.messages[j];
                if( message.attachment && message.attachment != '' && fs.existsSync( message.attachment )){
                    fs.unlinkSync( message.attachment );
                }
            }
        }
    } catch (error) {
        console.error( 'DELETING CHAT ATTACHMENTS' );
        console.error( error.message );
    }
}

/****************************************************************************
 * FUNCTION : REPORT STORY
 * This function reports about story
 * @param {*} data Data OBJECT
 * { "reported_by" : STRING ,"reported_to" : STRING, "reason" : STRING, 'storyId' : STRING }
 ****************************************************************************/
async function reportStory( data ){
    try {
        await REPORT.create({
            type : 'story',
            reported_by : data.reported_by,
            reported_to : data.reported_to,
            reason : data.reason,
            storyId : data.storyId,
        });
        callback({status : true, message : 'Reported Successfully'});
    } catch (error) {
        callback({status : false, message : error.message });
    }
}

/****************************************************************************
 * FUNCTION : REPORT USER
 * This function reports about user
 * @param {*} data Data OBJECT
 * { "reported_by" : STRING ,"reported_to" : STRING, "reason" : STRING }
 ****************************************************************************/
async function reportUser( data ){
    try {
        await REPORT.create({
            type : 'user',
            reported_by : data.reported_by,
            reported_to : data.reported_to,
            reason : data.reason,
            storyId : '',
        });
        callback({status : true, message : 'Reported Successfully'});
    } catch (error) {
        callback({status : false, message : error.message });
    }
}

// EXPORT ALL FUNCTION IN FILE
module.exports = { 
    deleteUserAccount,
    deleteChatAttachments,
    reportStory,
    reportUser,
}