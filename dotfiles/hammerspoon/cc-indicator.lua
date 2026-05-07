-- cc-indicator: aggregates per-session Claude Code state files into
-- at-most-two dots: review (assistant finished, awaiting glance) and
-- blocked (waiting on user input or tool approval).
--
-- state dir: ~/.claude/cc-indicator/sessions/<session_id>
-- file contents: "review" | "blocked"
-- file absent: idle.

local M = {}

local STATE_DIR = os.getenv("HOME") .. "/.claude/cc-indicator/sessions"

local REVIEW_COLOR  = { red = 0.18, green = 0.80, blue = 0.36, alpha = 1 } -- green
local BLOCKED_COLOR = { red = 1.00, green = 0.30, blue = 0.25, alpha = 1 } -- red

local overlay
local menubarReview
local menubarBlocked
local watcher
local debounceTimer

local function readState()
  local hasReview, hasBlocked = false, false
  pcall(function()
    for f in hs.fs.dir(STATE_DIR) do
      if f ~= "." and f ~= ".." then
        local fh = io.open(STATE_DIR .. "/" .. f, "r")
        if fh then
          local s = (fh:read("*l") or ""):gsub("%s+", "")
          fh:close()
          if s == "blocked" then hasBlocked = true
          elseif s == "review" then hasReview = true end
        end
      end
    end
  end)
  return hasReview, hasBlocked
end

local function buildOverlay()
  -- top-right of primary screen, just under menu bar so it sits near the
  -- mac mic/camera indicator zone. fullScreenAuxiliary lets it ride along
  -- into fullscreen spaces.
  local frame = hs.screen.primaryScreen():fullFrame()
  local w, h = 44, 14
  local x = frame.x + frame.w - w - 8
  local y = frame.y + 4

  overlay = hs.canvas.new({ x = x, y = y, w = w, h = h })
  overlay:level(hs.canvas.windowLevels.overlay)
  overlay:behavior({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary" })
  overlay:clickActivating(false)

  -- two slots; alpha toggled to show/hide
  overlay[1] = {
    type = "circle", action = "fill",
    fillColor = REVIEW_COLOR,
    center = { x = 11, y = 7 }, radius = 5,
  }
  overlay[2] = {
    type = "circle", action = "fill",
    fillColor = BLOCKED_COLOR,
    center = { x = 33, y = 7 }, radius = 5,
  }
  overlay[1].action = "skip"
  overlay[2].action = "skip"
  overlay:show()
end

local function setSlot(idx, visible)
  if not overlay then return end
  overlay[idx].action = visible and "fill" or "skip"
end

local function ensureMenubar()
  if not menubarReview then menubarReview = hs.menubar.new(false) end
  if not menubarBlocked then menubarBlocked = hs.menubar.new(false) end
end

local function setMenubar(item, visible, glyph, tooltip)
  if visible then
    item:setTitle(glyph)
    item:setTooltip(tooltip)
    item:returnToMenuBar()
  else
    item:removeFromMenuBar()
  end
end

local function render()
  local r, b = readState()
  setSlot(1, r)
  setSlot(2, b)
  ensureMenubar()
  setMenubar(menubarReview,  r, "🟢", "Claude Code: ready for review")
  setMenubar(menubarBlocked, b, "🔴", "Claude Code: waiting on you")
end

local function scheduleRender()
  if debounceTimer then debounceTimer:stop() end
  debounceTimer = hs.timer.doAfter(0.05, render)
end

function M.start()
  hs.execute("/bin/mkdir -p '" .. STATE_DIR .. "'")
  buildOverlay()
  ensureMenubar()
  render()
  watcher = hs.pathwatcher.new(STATE_DIR, scheduleRender):start()
end

function M.stop()
  if watcher then watcher:stop(); watcher = nil end
  if overlay then overlay:delete(); overlay = nil end
  if menubarReview then menubarReview:delete(); menubarReview = nil end
  if menubarBlocked then menubarBlocked:delete(); menubarBlocked = nil end
end

return M
