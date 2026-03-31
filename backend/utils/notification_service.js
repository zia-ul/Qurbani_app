const axios = require("axios");

const sendPushNotification = async (
  subscriptionIds,
  title,
  message,
  data = {}
) => {
  if (!subscriptionIds || subscriptionIds.length === 0) return;
    console.log("Preparing to send push notification");
    console.log(process.env.ONESIGNAL_REST_API_KEY, process.env.APP_ID_ONE_SIGNAL);
  await axios.post(
    "https://api.onesignal.com/notifications",
    {
      app_id: process.env.APP_ID_ONE_SIGNAL,
      include_subscription_ids: subscriptionIds,
      headings: { en: title },
      contents: { en: message },
      data: data, 
    },
    {
      headers: {
        Authorization: `Key ${process.env.ONESIGNAL_REST_API_KEY}`,
        "Content-Type": "application/json",
      },
    }
  );
};

module.exports = { sendPushNotification };