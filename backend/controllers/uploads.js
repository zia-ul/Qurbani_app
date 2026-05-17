const express = require("express");
const supabase = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const upload = require("../middleware/upload_middleware");
const logger = require("../middleware/logger");
const { uploadBuffer, cloudinary } = require("../services/cloudinary_service");

const router = express.Router();

const allowedContexts = new Set([
  "profile",
  "animal_gallery",
  "admin_verification",
  "chat_media",
  "gallery",
  "document",
  "general",
]);

function normalizeContext(rawContext) {
  const context = (rawContext || "general")
    .toString()
    .trim();

  return allowedContexts.has(context)
    ? context
    : "general";
}

function cloudinaryFolder(userId, context) {
  return `qurbani/${context}/${userId}`;
}

async function persistUpload(
  userId,
  context,
  file,
  result
) {

  const { data, error } = await supabase
    .from("user_uploads")
    .insert([
      {
        user_id: userId,
        context,
        original_name:
          file.originalname || null,
        mime_type:
          file.mimetype || null,
        size_bytes:
          file.size || null,
        cloudinary_public_id:
          result.public_id,
        secure_url:
          result.secure_url,
        resource_type:
          result.resource_type || null,
      },
    ])
    .select()
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data;
}

router.post(
  "/",
  authMiddleware,
  upload.array("files", 10),
  async (req, res) => {

    const userId = req.user.id;

    const context = normalizeContext(
      req.body.context
    );

    const files = req.files || [];

    if (files.length === 0) {
      return res.status(400).json({
        message:
          "At least one file is required",
      });
    }

    // Track uploaded Cloudinary assets
    // so we can cleanup on failure
    const uploadedPublicIds = [];

    try {

      const uploadedFiles = [];

      for (const file of files) {

        // Upload to Cloudinary
        const result = await uploadBuffer(
          file,
          {
            folder: cloudinaryFolder(
              userId,
              context
            ),
          }
        );

        uploadedPublicIds.push(
          result.public_id
        );

        // Save metadata to Supabase
        const savedUpload =
          await persistUpload(
            userId,
            context,
            file,
            result
          );

        uploadedFiles.push({
          id: savedUpload.id,
          url: result.secure_url,
          secure_url:
            result.secure_url,
          public_id:
            result.public_id,
          resource_type:
            result.resource_type,
          original_name:
            file.originalname,
          mime_type:
            file.mimetype,
          size_bytes:
            file.size,
          created_at:
            savedUpload.created_at,
        });
      }

      return res.status(201).json({
        message:
          "Files uploaded successfully",
        urls: uploadedFiles.map(
          (f) => f.url
        ),
        files: uploadedFiles,
      });

    } catch (err) {

      // Cleanup orphaned uploads
      for (const publicId of uploadedPublicIds) {

        try {

          await cloudinary.uploader.destroy(
            publicId
          );

        } catch (cleanupErr) {

          logger.error(
            "Cloudinary cleanup failed",
            {
              publicId,
              error:
                cleanupErr.message,
            }
          );
        }
      }

      logger.error(
        "File upload failed",
        {
          userId,
          context,
          error: err.message,
        }
      );

      const isValidationError =
        err.message.includes(
          "Unsupported file type"
        ) ||
        err.message.includes(
          "File too large"
        );

      return res.status(
        isValidationError ? 400 : 500
      ).json({
        message:
          err.message ||
          "Unable to upload files",
      });
    }
  }
);

router.use(
  (err, req, res, next) => {

    if (!err) {
      return next();
    }

    logger.warn(
      "Upload request rejected",
      {
        userId: req.user?.id,
        error: err.message,
      }
    );

    return res.status(400).json({
      message:
        err.message || "Invalid upload",
    });
  }
);

module.exports = router;