// email_service.js
const nodemailer = require('nodemailer');
const dotenv = require('dotenv');
dotenv.config();

const _baseUrl = process.env.BASE_URL;
// Create transporter with Gmail SMTP (SSL)
const createTransporter = async () => {
  // const testAccount = await nodemailer.createTestAccount();

  const transporter = nodemailer.createTransport({
    host: 'smtp.ethereal.email',
    port: 587,
    secure: false, // TLS
    auth: {
      user: 'conor.cruickshank78@ethereal.email',
      pass: 'xMcAWCNv9VvtXSzubP'
    },
  });
};

createTransporter();

// Verify connection configuration
// transporter.verify(function (error, success) {
//   if (error) {
//     console.error('Nodemailer transporter error:', error);
//   } else {
//     console.log('Nodemailer is ready to send emails');
//   }
// });

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
