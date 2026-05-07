-- toolbox-managed Hammerspoon entrypoint.

hs.autoLaunch(true)
hs.allowAppleScript(true)   -- enables `osascript ... execute lua code` for debugging
pcall(function() require("hs.ipc").cliInstall() end)
hs.menuIcon(false)
hs.console.clearConsole()

local ok, err = pcall(function()
  require("cc-indicator").start()
end)
if not ok then
  _G.ccErr = tostring(err)
  hs.alert.show("cc-indicator failed: " .. tostring(err), 5)
else
  hs.alert.show("Hammerspoon loaded")
end
