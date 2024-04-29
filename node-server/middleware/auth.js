const jwt    = require("jsonwebtoken");
const SERVER_TOKEN_KEY = 'vOVH6sdmpNWjRRIqCc7rdxs01lwHzfr3';

// This function verify user token
const verifyToken = (req, res, next) => {
    // Get token from user request
    const token = req.body.token || req.query.token || req.headers["x-access-token"];
    // If token not exist then return error
    if (!token) {
      return res.status(403).json({code: "TOKEN_MISSING", message: "A token is required for authentication. Please login again & try."});
    }
    // If token exist then check validity
    try {
      const decoded = jwt.verify(token, SERVER_TOKEN_KEY);
      req.user = decoded;
    } catch (err) {
      // If token is invalid then return error
      return res.status(403).json({code: "TOKEN_EXPIRED", message: "Session Expired. Kindly Login again to continue"});
    }
    // Pass the request to next route
    return next();
  };
  // Export function
  module.exports = verifyToken;