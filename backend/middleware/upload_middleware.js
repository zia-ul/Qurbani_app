const multer = require("multer");
const path = require("path");

const allowedMimeTypes = new Set([
"image/jpeg",
"image/jpg",
"image/png",
"image/webp",
"image/gif",
"image/heic",
"image/heif",
"application/pdf",
]);

const allowedExtensions = new Set([
".jpg",
".jpeg",
".png",
".webp",
".gif",
".heic",
".heif",
".pdf",
]);

const upload = multer({
storage: multer.memoryStorage(),

limits: {
fileSize: 10 * 1024 * 1024,
files: 10,
},

fileFilter: (req, file, cb) => {
console.log("UPLOAD FILE:", {
originalname: file.originalname,
mimetype: file.mimetype,
});


const ext = path.extname(file.originalname).toLowerCase();

const mimeAllowed =
  allowedMimeTypes.has(file.mimetype);

const extensionAllowed =
  allowedExtensions.has(ext);

const isGenericBinary =
  file.mimetype === "application/octet-stream";

// Accept:
// 1. known good MIME types
// 2. generic binary files WITH valid image/pdf extensions
if (
  mimeAllowed ||
  (isGenericBinary && extensionAllowed)
) {
  return cb(null, true);
}

return cb(
  new Error(
    `Unsupported file type: ${file.mimetype}`
  )
);


},
});

module.exports = upload;
