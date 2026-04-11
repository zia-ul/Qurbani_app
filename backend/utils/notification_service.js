const axios = require("axios");
const logger = require("../middleware/logger");

const sendPushNotification = async (
  subscriptionIds,
  title,
  message,
  data = {}
) => {
  if (!subscriptionIds || subscriptionIds.length === 0) {
    return false;
  }

  if (!process.env.APP_ID_ONE_SIGNAL || !process.env.ONESIGNAL_REST_API_KEY) {
    logger.warn("Skipping push notification because OneSignal env is missing", {
      hasAppId: Boolean(process.env.APP_ID_ONE_SIGNAL),
      hasRestApiKey: Boolean(process.env.ONESIGNAL_REST_API_KEY),
      subscriptionCount: subscriptionIds.length,
      title,
    });
    return false;
  }

  try {
    await axios.post(
      "https://api.onesignal.com/notifications",
      {
        app_id: process.env.APP_ID_ONE_SIGNAL,
        include_subscription_ids: subscriptionIds,
        headings: { en: title },
        contents: { en: message },
        data,
      },
      {
        headers: {
          Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
          "Content-Type": "application/json",
        },
      }
    );

    return true;
  } catch (error) {
    logger.error("Push notification failed", {
      title,
      subscriptionCount: subscriptionIds.length,
      error: error.message,
      statusCode: error.response?.status,
      responseBody: error.response?.data,
    });
    return false;
  }
};

module.exports = { sendPushNotification };
