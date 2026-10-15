/**
 * Cross-platform desktop notification plugin for opencode.
 *
 * Fallback for opencode's built-in `attention` system. It is disabled in
 * opencode.jsonc; re-enable the `plugin` entry there to use this instead
 * of (or in addition to) tui.json.
 *
 * Notifies only when input is needed or a run finishes:
 *   - question.asked      the agent asked the user a question
 *   - permission.asked    a tool is waiting for approval (also a question)
 *   - session.idle        a top-level session finished responding
 *
 * On Linux the notification carries a "Focus" action. Clicking it raises the
 * kitty window running opencode (via niri). It never moves the window on its
 * own, and does nothing when the notification daemon lacks action support.
 *
 * Uses the `$` (Bun shell) that opencode injects into every plugin, so it
 * needs no extra npm dependencies.
 */

const isDarwin = process.platform === "darwin";
const isLinux = process.platform === "linux";

// Freedesktop sound theme that ships with NixOS.
const SOUND_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo";

export const NotificationPlugin = async ({ client, $ }) => {
  // Raise the kitty window hosting this opencode instance. Only ever called
  // from a notification action, never automatically.
  const focusWindow = async () => {
    try {
      const pid = process.env.KITTY_PID;
      if (!pid || !process.env.NIRI_SOCKET) return;
      const raw = await $`niri msg -j windows`.quiet().text();
      const win = JSON.parse(raw).find((w) => String(w.pid) === String(pid));
      if (win) await $`niri msg action focus-window --id ${win.id}`.quiet();
    } catch {
      // Focusing is best-effort.
    }
  };

  const notify = async (title, message, { urgency = "normal" } = {}) => {
    try {
      if (isDarwin) {
        const script = `display notification ${JSON.stringify(message)} with title ${JSON.stringify(title)}`;
        await $`osascript -e ${script}`.quiet();
      } else if (isLinux) {
        // `--wait` blocks until the notification is closed and prints the
        // chosen action ("default" when the user clicks Focus). Daemons
        // without action support simply print nothing.
        const action =
          await $`notify-send -a opencode -u ${urgency} -A default=Focus --wait ${title} ${message}`
            .quiet()
            .text();
        if (action.trim() === "default") await focusWindow();
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
          let session;
          try {
            session = await client.session.get({ path: { id: props.sessionID } });
          } catch {
            // Fall back to generic details.
          }
          // Subagents go idle constantly; only the top-level session matters.
          if (session?.data?.parentID) break;
          const title = session?.data?.title ?? "Task complete";
          await playSound("complete");
          void notify(title, "opencode finished responding");
          break;
        }

        case "question.asked": {
          await playSound("dialog-warning");
          void notify("opencode has a question", "opencode is waiting for your answer", {
            urgency: "critical",
          });
          break;
        }

        case "permission.asked": {
          const what = props.permission ?? props.type ?? "a tool";
          await playSound("dialog-warning");
          void notify("opencode needs approval", `Permission required for: ${what}`, {
            urgency: "critical",
          });
          break;
        }
      }
    },
  };
};
