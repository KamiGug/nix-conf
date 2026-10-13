/**
 * Cross-platform desktop notification plugin for opencode.
 *
 * Notifies on:
 *   - session.idle       the agent finished responding
 *   - session.error      a session/provider error occurred
 *   - permission.asked   a tool is waiting for approval
 *   - permission.replied an approval was granted/rejected
 *
 * Uses the `$` (Bun shell) that opencode injects into every plugin, so it
 * needs no extra npm dependencies.
 */

const isDarwin = process.platform === "darwin";
const isLinux = process.platform === "linux";

// Freedesktop sound theme that ships with NixOS.
const SOUND_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo";

export const NotificationPlugin = async ({ client, $ }) => {
  const notify = async (title, message, { urgency = "normal" } = {}) => {
    try {
      if (isDarwin) {
        const script = `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`;
        await $`osascript -e ${script}`.quiet();
      } else if (isLinux) {
        await $`notify-send -a opencode -u ${urgency} ${title} ${message}`.quiet();
      }
    } catch (error) {
      console.error("opencode notification failed:", error);
    }
  };

  const playSound = async (name) => {
    try {
      if (isDarwin) {
        await $`afplay /System/Library/Sounds/${name}.aiff`.quiet();
      } else if (isLinux) {
        await $`pw-play ${SOUND_DIR}/${name}.oga`.quiet();
      }
    } catch {
      // Sound is best-effort.
    }
  };

  return {
    event: async ({ event }) => {
      // opencode hands plugins `{ id, type, properties }`, where `properties`
      // is the event payload.
      const props = event.properties ?? {};

      switch (event.type) {
        case "session.idle": {
          let title = "Task complete";
          try {
            const session = await client.session.get({ path: { id: props.sessionID } });
            if (session.data?.title) title = session.data.title;
          } catch {
            // Fall back to the generic title.
          }
          await notify(title, "opencode finished responding");
          await playSound("complete");
          break;
        }

        case "session.error": {
          const message =
            props.error?.data?.message ?? props.error?.message ?? "An error occurred";
          await notify("opencode error", message, { urgency: "critical" });
          await playSound("dialog-error");
          break;
        }

        case "permission.asked": {
          const what = props.permission ?? props.type ?? "a tool";
          await notify("opencode needs approval", `Permission required for: ${what}`, {
            urgency: "critical",
          });
          await playSound("dialog-warning");
          break;
        }

        case "permission.replied": {
          if (props.reply === "reject") break;
          await notify("opencode approval granted", `Permission ${props.reply ?? "granted"}`, {
            urgency: "low",
          });
          break;
        }
      }
    },
  };
};
