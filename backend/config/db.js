require("dotenv").config();

const { Pool } = require("pg");

const db = new Pool({
  host: "aws-1-ap-southeast-1.pooler.supabase.com",
  port: 6543,
  user: "postgres.qauvcdaenictojcjvljt",
  password: process.env.DB_PASSWORD,
  database: "postgres",
  ssl: {
    rejectUnauthorized: false,
  },
});

module.exports = db;