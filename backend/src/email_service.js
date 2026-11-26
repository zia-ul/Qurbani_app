// email_service.js
const nodemailer = require('nodemailer');
const https = require('https');
const dotenv = require('dotenv');
dotenv.config();

const RELAY_URL = process.env.MAIL_RELAY_URL || "https://www.aiconfidencecure.com/api/send-email";
const RELAY_SECRET = process.env.MAIL_RELAY_SECRET || "qurbani_secure_relay_2026";

// Direct transporter for local development / servers where SMTP ports are open
const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST || 'smtpout.secureserver.net', 
  port: process.env.EMAIL_PORT ? Number(process.env.EMAIL_PORT) : 465,
  secure: process.env.EMAIL_SECURE !== 'false',
  auth: {
    user: process.env.EMAIL_USER || 'support@aiconfidencecure.com',
    pass: process.env.EMAIL_PASS || 'Daniya@aiconfidencecure.com',
  },
  connectionTimeout: 8000,
  greetingTimeout: 8000,
  socketTimeout: 10000,
  tls: { rejectUnauthorized: false }
});

/**
 * Dispatch email via HTTPS Relay (ideal for Cloud/Render) with fallback to SMTP
 */
async function dispatchEmail({ to, subject, html, text }) {
  // First attempt: HTTPS Mail Relay to bypass Cloud SMTP port blocks (Render)
  try {
    const postData = JSON.stringify({
      to,
      subject,
      html,
      text,
      from: '"Qurbani App" <support@aiconfidencecure.com>',
      replyTo: 'support@aiconfidencecure.com'
    });

    const relayResult = await new Promise((resolve, reject) => {
      const url = new URL(RELAY_URL);
      const req = https.request(
        {
          hostname: url.hostname,
          path: url.pathname + (url.search || ""),
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-relay-secret": RELAY_SECRET,
            "Content-Length": Buffer.byteLength(postData)
          },
          timeout: 8000
        },
        (res) => {
          let body = "";
          res.on("data", chunk => body += chunk);
          res.on("end", () => {
            if (res.statusCode >= 200 && res.statusCode < 300) {
              resolve(JSON.parse(body || "{}"));
            } else {
              reject(new Error(`Relay returned status ${res.statusCode}: ${body}`));
            }
          });
        }
      );

      req.on("timeout", () => {
        req.destroy();
        reject(new Error("HTTPS Relay request timed out"));
      });

      req.on("error", (e) => reject(e));
      req.write(postData);
      req.end();
    });

    console.log("✅ Email sent via HTTPS Relay:", relayResult.messageId || "Success");
    return relayResult;
  } catch (relayErr) {
    console.warn("⚠️ HTTPS Relay failed, attempting direct SMTP fallback:", relayErr.message);
    // Fallback attempt: Direct SMTP
    return await transporter.sendMail({
      from: '"Qurbani App" <support@aiconfidencecure.com>',
      replyTo: 'support@aiconfidencecure.com',
      to,
      subject,
      html,
      text
    });
  }
}

/**
 * Send verification email to user
 * @param {string} toEmail - Recipient email
 * @param {string} otp - 6-Digit OTP code
 * @param {string} token - Verification token
 */
const sendVerificationEmail = async (toEmail, otp, token) => {
  const backendUrl = process.env.BASE_URL && !process.env.BASE_URL.includes("localhost") && !process.env.BASE_URL.includes("192.168")
    ? process.env.BASE_URL
    : "https://qurbani-backend-nxny.onrender.com/api";
  
  const verifyTokenOrOtp = token || otp;
  const verifyLink = `${backendUrl}/auth/verify-email?token=${encodeURIComponent(verifyTokenOrOtp)}`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 10px; background-color: #ffffff;">
      <h2 style="color: #2F6F4E; text-align: center; margin-top: 0;">Welcome to Qurbani!</h2>
      <p style="font-size: 15px; color: #333;">Hello,</p>
      <p style="font-size: 15px; color: #555; line-height: 1.5;">
        Thank you for registering with Qurbani. Please use your 6-digit verification code below to complete registration:
      </p>

      <div style="background-color: #f7faf8; border: 1px solid #d4e8dd; border-radius: 8px; padding: 18px; margin: 24px 0; text-align: center;">
        <p style="margin: 0 0 10px 0; font-size: 14px; font-weight: bold; color: #2F6F4E; text-transform: uppercase; letter-spacing: 1px;">
          Your 6-Digit Verification Code
        </p>
        <span style="font-size: 34px; font-weight: bold; letter-spacing: 8px; color: #2F6F4E; background: #ffffff; padding: 10px 20px; border-radius: 6px; display: inline-block; border: 2px dashed #2F6F4E;">
          ${otp}
        </span>
      </div>

      <div style="text-align: center; margin: 30px 0 20px 0;">
        <p style="margin: 0 0 14px 0; font-size: 14px; color: #666;">
          Or click the button below to verify instantly in your browser:
        </p>
        <a href="${verifyLink}" target="_blank" style="background-color: #2F6F4E; color: #ffffff; padding: 14px 28px; text-decoration: none; font-size: 16px; font-weight: bold; border-radius: 6px; display: inline-block;">
          Verify Email Now
        </a>
      </div>

      <p style="color: #888; font-size: 12px; text-align: center; margin-top: 25px; word-break: break-all;">
        If the button above does not work, copy and paste this link into your browser:<br/>
        <a href="${verifyLink}" style="color: #2F6F4E;">${verifyLink}</a>
      </p>

      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
      <p style="color: #999; font-size: 12px; margin: 0; text-align: center;">
        This code and link will expire in 15 minutes. If you did not create an account, please ignore this email.
      </p>
    </div>
  `;

  return await dispatchEmail({
    to: toEmail,
    subject: "Verify Your Email - Qurbani App",
    text: `Your Qurbani App verification code is: ${otp}. This code is valid for 15 minutes.`,
    html
  });
};

/**
 * Send password reset OTP or link email
 * @param {string} toEmail - Recipient email
 * @param {string} otpOrToken - Reset OTP or Token
 */
const sendPasswordResetEmail = async (toEmail, otpOrToken) => {
  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 8px;">
      <h2 style="color: #2F6F4E; text-align: center;">Reset Your Password</h2>
      <p>Hello,</p>
      <p>We received a request to reset your password for your Qurbani account.</p>
      <div style="text-align: center; margin: 30px 0;">
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #2F6F4E; background: #eaf4ee; padding: 12px 24px; border-radius: 6px; display: inline-block;">
          ${otpOrToken}
        </span>
      </div>
      <p style="color: #666; font-size: 14px;">Use this 6-digit verification code to reset your password in the mobile app. This code is valid for 15 minutes.</p>
      <p style="color: #999; font-size: 12px;">If you did not request this password reset, please ignore this email or contact support.</p>
    </div>
  `;

  return await dispatchEmail({
    to: toEmail,
    subject: "Password Reset Code - Qurbani App",
    text: `Your password reset code is: ${otpOrToken}`,
    html
  });
};

module.exports = { sendVerificationEmail, sendPasswordResetEmail };
