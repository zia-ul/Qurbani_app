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

// Export function using CommonJS
module.exports = { sendVerificationEmail };
