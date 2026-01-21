const { createLogger, format, transports } = require("winston");
const DailyRotateFile = require("winston-daily-rotate-file");

const { combine, timestamp, printf, json } = format;

const logFormat = printf(({ timestamp, level, message, ...meta }) => {
  return `${timestamp} [${level}]: ${message} ${
    Object.keys(meta).length ? JSON.stringify(meta) : ""
  }`;
});

const dailyRotateTransport = new DailyRotateFile({
  filename: "logs/app-%DATE%.log",
  datePattern: "YYYY-MM-DD",
  maxFiles: "7d",
  zippedArchive: true,
});

const errorRotateTransport = new DailyRotateFile({
  filename: "logs/error-%DATE%.log",
  datePattern: "YYYY-MM-DD",
  level: "error",
  maxFiles: "7d",
  zippedArchive: true,
});

const logger = createLogger({
  level: process.env.NODE_ENV === "production" ? "info" : "debug",
  format: combine(
    timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
    logFormat
  ),
  transports: [
    dailyRotateTransport,
    errorRotateTransport,
    new transports.Console(),
  ],
  exitOnError: false,
});

module.exports = logger;
