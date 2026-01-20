const logger = require("./logger");

module.exports = (req, res, next) => {
  logger.info("Incoming request", {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip
  });
  next();
};
