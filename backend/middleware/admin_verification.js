const supabase = require("../config/db");

const requireApprovedAdmin = async (
  req,
  res,
  next
) => {

  try {

    if (req.user.role !== "admin") {
      return res.sendStatus(403);
    }

    const { data, error } =
      await supabase
        .from(
          "admin_verification_requests"
        )
        .select("status")
        .eq("user_id", req.user.id)
        .single();

    if (error && error.code !== "PGRST116") {
      throw new Error(error.message);
    }

    // No verification request found
    if (!data) {
      return res.status(403).json({
        message:
          "Admin verification not submitted",
      });
    }

    // Verification exists but not approved
    if (data.status !== "approved") {
      return res.status(403).json({
        message:
          "Admin verification pending approval",
      });
    }

    next();

  } catch (err) {

    console.error(
      "Admin approval middleware error:",
      err.message
    );

    return res.status(500).json({
      message:
        "Internal server error",
    });
  }
};

module.exports = requireApprovedAdmin;