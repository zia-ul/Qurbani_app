const nodemailer = require("nodemailer");
const dotenv = require("dotenv");

dotenv.config();

const baseUrl = process.env.BASE_URL;

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

if (!process.env.VERCEL) {
  transporter.verify((error) => {
    if (error) {
      console.error("Nodemailer error:", error);
    } else {
      console.log("Nodemailer ready to send emails");
    }
  });
}

const sendVerificationEmail = async (toEmail, token) => {
  const verificationUrl = `${baseUrl}/auth/verify-email?token=${token}`;

  const info = await transporter.sendMail({
    from: '"Qurbani App" <no-reply@qurbani.com>',
    to: toEmail,
    subject: "Email Verification",
    html: `
      <h3>Welcome to Qurbani!</h3>
      <p>Please verify your email by clicking the link below:</p>
      <a href="${verificationUrl}">Verify Email</a>
      <p>This link will expire in 24 hours.</p>
    `,
  });

  console.log("Message ID:", info.messageId);
  console.log("Preview URL:", nodemailer.getTestMessageUrl(info));

  return info;
};

module.exports = { sendVerificationEmail };
