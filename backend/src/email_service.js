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


const sendVerificationEmail = async (toEmail, token) => {
  const verificationUrl = `${_baseUrl}/auth/verify-email?token=${token}`;

  const info = await transporter.sendMail({
    from: '"Qurbani App" <no-reply@qurbani.com>',
    to: toEmail,
    subject: 'Email Verification',
    html: `
      <h3>Welcome to Qurbani!</h3>
      <p>Please verify your email by clicking the link below:</p>
      <a href="${verificationUrl}">Verify Email</a>
      <p>This link will expire in 24 hours.</p>
    `,
  });

  console.log('Message ID:', info.messageId);
  console.log('Preview URL:', nodemailer.getTestMessageUrl(info));

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
      from: '"Qurbani App" <no-reply@qurbani.com>',
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
