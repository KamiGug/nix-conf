hs.loadSpoon("SpoonInstall")

-- Require your standalone keymaps file
local keymaps = require("paper-wm.keymaps")

spoon.SpoonInstall.repos.PaperWM = {
    url = "https://github.com/mogenson/PaperWM.spoon",
    desc = "PaperWM.spoon repository",
    branch = "release",
}

-- Let SpoonInstall manage downloading, starting, and binding keys safely
spoon.SpoonInstall:andUse("PaperWM", {
    repo = "PaperWM",
    config = { screen_margin = 16, window_gap = 2 },
    start = true,
    fn = function(spoon_instance)
        -- Wire up your keymaps safely inside the post-load callback
        spoon_instance:bindHotkeys(keymaps.bindings)
    end
})
