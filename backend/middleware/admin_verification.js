const requireApprovedAdmin = async (req, res, next) => {
  if (req.user.role !== 'admin') return res.sendStatus(403);

  const [rows] = await db.query(
    `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
    [req.user.id]
  );

  if (rows.length === 0) {
    return res.status(403).json({
      message: 'Admin verification not submitted'
    });
  }

  if (rows[0].status !== 'approved') {
    return res.status(403).json({
      message: 'Admin verification pending approval'
    });
  }

  next();
};
