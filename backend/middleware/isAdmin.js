module.exports = (req, res, next) => {
  if (
    req.user.role !== "admin" ||
    req.user.admin_status !== "approved"
  ) {
    return res.status(403).json({
      message: "Admin access required",
    });
  }

  next();
};
