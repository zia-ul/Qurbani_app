const axios = require("axios");

const sendPushNotification = async (subscriptionIds, title, message) => {
  if (!subscriptionIds || subscriptionIds.length === 0) return;

  try {
    await axios.post(
      "https://api.onesignal.com/notifications",
      {
        app_id: process.env.ONESIGNAL_APP_ID,
        include_subscription_ids: subscriptionIds,
        headings: { en: title },
        contents: { en: message },
      },
      {
        headers: {
          Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Push notification failed:",
      error.response?.data || error.message
    );
  }
};

module.exports = { sendPushNotification };