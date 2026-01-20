const { createLogger, format, transports } = require('winston');
const { combine, timestamp, printf, colorize } = format;

// Custom log format
const myFormat = printf(({ level, message, timestamp }) => {
  return `${timestamp} [${level}]: ${message}`;
});

// Create Winston logger
const logger = createLogger({
  level: 'info', // default level
  format: combine(
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    colorize(),
    myFormat
  ),
  transports: [
    new transports.Console(), // logs to console
    new transports.File({ filename: 'logs/error.log', level: 'error' }), // error log
    new transports.File({ filename: 'logs/combined.log' }) // all logs
  ],
});

module.exports = logger;
