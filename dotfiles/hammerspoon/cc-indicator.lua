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
local visibilityTimer
local syncTimer
local overlayHidden = false

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

local function slotElement(fillColor, cx, visible)
  return {
    type = "circle",
    action = visible and "fill" or "skip",
    fillColor = fillColor,
    center = { x = cx, y = 7 },
    radius = 5,
  }
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

  overlay:replaceElements({
    slotElement(REVIEW_COLOR,  11, false),
    slotElement(BLOCKED_COLOR, 33, false),
  })
  overlay:show()
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
  if overlay then
    overlay:replaceElements({
      slotElement(REVIEW_COLOR,  11, r),
      slotElement(BLOCKED_COLOR, 33, b),
    })
  end
  ensureMenubar()
  setMenubar(menubarReview,  r, "🟢", "Claude Code: ready for review")
  setMenubar(menubarBlocked, b, "🔴", "Claude Code: waiting on you")
end

local function updateOverlayVisibility()
  if not overlay then return end
  local screen = hs.screen.primaryScreen()
  local screenFrame = screen:fullFrame()
  local spaceID = hs.spaces.focusedSpace()
  local spaceType = spaceID and hs.spaces.spaceType(spaceID) or "user"
  local menubarVisible
  if spaceType ~= "fullscreen" then
    -- normal desktop space: menubar always present
    menubarVisible = true
  else
    -- fullscreen space: menubar auto-hides, revealed only when cursor near top
    local m = hs.mouse.absolutePosition() or hs.mouse.getAbsolutePosition()
    menubarVisible = m.y <= screenFrame.y + 30
  end
  if menubarVisible and not overlayHidden then
    overlay:hide()
    overlayHidden = true
  elseif not menubarVisible and overlayHidden then
    overlay:show()
    overlayHidden = false
  end
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
  visibilityTimer = hs.timer.doEvery(0.2, updateOverlayVisibility):start()
  syncTimer = hs.timer.doEvery(1.0, render):start()
end

function M.stop()
  if watcher then watcher:stop(); watcher = nil end
  if visibilityTimer then visibilityTimer:stop(); visibilityTimer = nil end
  if syncTimer then syncTimer:stop(); syncTimer = nil end
  if overlay then overlay:delete(); overlay = nil end
  if menubarReview then menubarReview:delete(); menubarReview = nil end
  if menubarBlocked then menubarBlocked:delete(); menubarBlocked = nil end
end

return M
