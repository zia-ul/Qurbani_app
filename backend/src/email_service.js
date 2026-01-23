// email_service.js
const nodemailer = require('nodemailer');
const dotenv = require('dotenv');
dotenv.config();

// Create transporter with Gmail SMTP (SSL)
const transporter = nodemailer.createTransport({
  host: 'smtp.gmail.com',
  port: 465,
  secure: true, // SSL
  auth: {
    user: process.env.EMAIL_USER, // your Gmail address
    pass: process.env.EMAIL_PASS, // your Gmail App Password
  },
});

// Verify connection configuration
transporter.verify(function (error, success) {
  if (error) {
    console.error('Nodemailer transporter error:', error);
  } else {
    console.log('Nodemailer is ready to send emails');
  }
});

/**
 * Send verification email to user
 * @param {string} toEmail - Recipient email
 * @param {string} token - Verification token
 */
const sendVerificationEmail = async (toEmail, token) => {
  try {
    const verificationUrl = `http://192.168.1.4:3000/api/auth/verify-email?token=${token}`;

    const mailOptions = {
      from: '"Qurbani App" <no-reply@qurbani.com>',
      to: toEmail,
      subject: 'Email Verification',
      html: `
        <h3>Welcome to Qurbani!</h3>
        <p>Please verify your email by clicking the link below:</p>
        <a href="${verificationUrl}">Verify Email</a>
        <p>This link will expire in 24 hours.</p>
      `,
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`Verification email sent to ${toEmail}: ${info.messageId}`);
    return info;
  } catch (err) {
    console.error(`Failed to send email to ${toEmail}:`, err);
    throw err;
  }
};

// Export function using CommonJS
module.exports = { sendVerificationEmail };
