// firefox-user.js — modest hardening for Firefox ESR on Kali.
// Copy into your profile dir: ~/.mozilla/firefox/<profile>.default-esr/user.js
// (Find the profile path at about:profiles.) These are conservative choices
// that don't break most sites. For full lockdown see arkenfox/user.js.

// --- telemetry & data collection off ---------------------------------------
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);

// --- privacy ----------------------------------------------------------------
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("network.cookie.cookieBehavior", 5);      // total cookie protection
user_pref("privacy.firstparty.isolate", true);
user_pref("dom.security.https_only_mode", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);
user_pref("browser.send_pings", false);

// --- search / suggestions ---------------------------------------------------
user_pref("browser.urlbar.suggest.searches", false);
user_pref("keyword.enabled", true);

// --- misc -------------------------------------------------------------------
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("geo.enabled", false);
user_pref("media.peerconnection.enabled", false);   // disable WebRTC (IP leak) — re-enable if you need video calls
