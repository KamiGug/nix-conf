/**
 * Cross-platform notification plugin for OpenCode
 * Supports Linux (notify-send) and macOS (osascript)
 * Notifies on: session.idle (task complete), session.error, permission.asked (question/permission needed)
 */

const { $ } = require("zx");

const isDarwin = process.platform === "darwin";
const isLinux = process.platform === "linux";

async function notify(title, message, options = {}) {
  const { sound = false, urgency = "normal" } = options;

  if (isDarwin) {
    const script = `
      display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}
      ${sound ? "sound name \"Glass\"" : ""}
    `;
    try {
      await $`osascript -e ${script}`;
    } catch (e) {
      console.error("Failed to send macOS notification:", e);
    }
  } else if (isLinux) {
    const args = ["notify-send", "-u", urgency, title, message];
    try {
      await $`${args}`;
    } catch (e) {
      console.error("Failed to send Linux notification:", e);
    }
  }
}

async function playSound(soundName) {
  if (isDarwin) {
    try {
      await $`afplay /System/Library/Sounds/${soundName}.aiff`;
    } catch (e) {
      // Ignore sound errors
    }
  } else if (isLinux) {
    try {
      await $`paplay /usr/share/sounds/freedesktop/stereo/${soundName}.oga`;
    } catch (e) {
      // Ignore sound errors
    }
  }
}

export const NotificationPlugin = async ({ project, client, $, directory, worktree }) => {
  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.idle": {
          const title = "OpenCode - Task Complete";
          const message = event.payload?.session?.title || "Session completed";
          await notify(title, message, { sound: true, urgency: "normal" });
          await playSound("complete");
          break;
        }
        case "session.error": {
          const title = "OpenCode - Error";
          const message = event.payload?.error?.message || "An error occurred";
          await notify(title, message, { sound: true, urgency: "critical" });
          await playSound("dialog-error");
          break;
        }
        case "permission.asked": {
          const title = "OpenCode - Permission Needed";
          const tool = event.payload?.tool || "unknown";
          const message = `Permission required for: ${tool}`;
          await notify(title, message, { sound: true, urgency: "critical" });
          await playSound("dialog-warning");
          break;
        }
        case "permission.updated": {
          if (event.payload?.status === "granted") {
            const title = "OpenCode - Permission Granted";
            const message = `Permission granted for: ${event.payload?.tool || "unknown"}`;
            await notify(title, message, { sound: false, urgency: "low" });
          }
          break;
        }
      }
    },
  };
};