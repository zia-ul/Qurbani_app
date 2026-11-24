// email_service.js
const nodemailer = require('nodemailer');
const dotenv = require('dotenv');
dotenv.config();

const _baseUrl = process.env.BASE_URL;

// Create transporter with Gmail SMTP (SSL)

const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com', 
  port: 587,
  secure: false, // TLS
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});



// Verify connection configuration
transporter.verify((error, success) => {
  if (error) {
    console.error('❌ Nodemailer error:', error);
  } else {
    console.log('✅ Nodemailer ready to send emails');
  }
});

/**
 * Send verification email to user
 * @param {string} toEmail - Recipient email
 * @param {string} token - Verification token
 */


const sendVerificationEmail = async (toEmail, otp, token) => {
  // Use public Render backend URL for verification link
  const backendUrl = process.env.BASE_URL && !process.env.BASE_URL.includes("localhost") && !process.env.BASE_URL.includes("192.168")
    ? process.env.BASE_URL
    : "https://qurbani-backend-nxny.onrender.com/api";
  
  // Link can use either verification token or otp
  const verifyTokenOrOtp = token || otp;
  const verifyLink = `${backendUrl}/auth/verify-email?token=${encodeURIComponent(verifyTokenOrOtp)}`;

  const info = await transporter.sendMail({
    from: '"Qurbani Support" <Support@aiconfidencecure.com>',
    replyTo: 'Support@aiconfidencecure.com',
    to: toEmail,
    subject: 'Verify Your Email - Qurbani App',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 10px; background-color: #ffffff;">
        <h2 style="color: #2F6F4E; text-align: center; margin-top: 0;">Welcome to Qurbani!</h2>
        <p style="font-size: 15px; color: #333;">Hello,</p>
        <p style="font-size: 15px; color: #555; line-height: 1.5;">
          Thank you for registering with Qurbani. You can verify your email and account using either of the two ways below:
        </p>

        <!-- Method 1: In-App 6-Digit OTP -->
        <div style="background-color: #f7faf8; border: 1px solid #d4e8dd; border-radius: 8px; padding: 18px; margin: 24px 0; text-align: center;">
          <p style="margin: 0 0 10px 0; font-size: 14px; font-weight: bold; color: #2F6F4E; text-transform: uppercase; letter-spacing: 1px;">
            1. Enter 6-Digit Code in App
          </p>
          <span style="font-size: 34px; font-weight: bold; letter-spacing: 8px; color: #2F6F4E; background: #ffffff; padding: 10px 20px; border-radius: 6px; display: inline-block; border: 2px dashed #2F6F4E;">
            ${otp}
          </span>
        </div>

        <!-- Method 2: One-Click Link -->
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
    `,
  });

  return info;
};

/**
 * Send password reset OTP or link email
 * @param {string} toEmail - Recipient email
 * @param {string} otpOrToken - Reset OTP or Token
 */
const sendPasswordResetEmail = async (toEmail, otpOrToken) => {
  try {
    const info = await transporter.sendMail({
      from: '"Qurbani Support" <Support@aiconfidencecure.com>',
      replyTo: 'Support@aiconfidencecure.com',
      to: toEmail,
      subject: 'Password Reset Code - Qurbani App',
      html: `
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
      `,
    });
    return info;
  } catch (error) {
    console.error('Failed to send password reset email:', error.message);
    throw error;
  }
};

// Export function using CommonJS
module.exports = { sendVerificationEmail, sendPasswordResetEmail };
