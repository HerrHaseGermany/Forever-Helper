# Forever Helper

WoW Forever Beta helper for interface 16001. Install this folder as
`Interface/AddOns/Forever Helper` and reload the game.

## Snapshots on reload and logout

Reload and normal shutdown capture the current snapshot. The next login and
`/fh recover` both select the newest saved snapshot for this character. Manual
recovery reapplies it even if restoration already succeeded earlier this session.
The old fixed rescue copy is only used when no regular snapshot is available;
it is not updated by the addon. New snapshots are persisted through SavedVariables.

On PLAYER_LOGOUT (including /reload), Forever Helper copies the active TomTom
and RestedXP preferences, TomTom frame positions, RestedXP guide and step, and
RestedXP-TomTom settings into its own per-character `ForeverHelperDB`.
An independent copy is also kept in account-wide `ForeverHelperAccountDB`,
indexed by player GUID. On login the newer copy is selected (account copy wins
ties), so an unavailable character file does not discard the backup. Existing
character backups migrate automatically. Initialization waits for entering the
world, when the player GUID is available.
It also backs up the PTR bug-report button's position and RestedXP's native
compressed cache of completed guide imports. The cache is restored before the
active guide, so that an imported guide can be selected again after a reload.
The copies contain plain values and do not share tables with the source addons.
CVars remain check-only. Other guides' progress and quest caches are not backed up.

After entering the world it waits one second, then restores available addons
once per session. Pending components retry for up to 60 attempts. Combat defers
restoration. Addons loaded later trigger another
attempt; unavailable addons keep their existing backups. Pending backups are
not replaced by defaults at logout. This delay is a practical initialization
window, not a guarantee against later resets by another addon.

This requires the beta to persist Forever Helper's own SavedVariables. A crash
or forced quit cannot reliably trigger saving. `/fh save` captures in memory;
WoW writes the data to disk on normal logout/reload.

## Test

1. Load Forever Helper and set your preferred addon positions and guide.
2. Use `/fh save` to capture them, then `/reload`.
3. Wait at least one second and use `/fh status`.
4. Check `Backup loaded at login` for the previous timestamp and each addon's
   `restored` status. Confirm the actual positions and guide step in game.
5. Repeat with normal quit and game restart.

`none (first run or not persisted)` on the next login means no saved timestamp
was loaded. `pending` means restoration has not succeeded; `/fh restore` retries
pending components after they are available. Existing restored components are
not repeatedly reset during zone transitions.

After updating, position the TomTom arrow and bug-report button where you want
them, finish any RestedXP guide imports, and run `/fh save` before `/reload`.
Older backups do not contain the button position or imported-guide cache.
The arrow is explicitly reanchored after TomTom refreshes its options.
The button uses Blizzard's `PTR_IssueReporter` frame and synchronizes its saved
coordinates; it does not copy bug-report contents or other feedback data.

`/fh status` includes `bugButton` and `importedGuides`. Incomplete imports are
not captured. An incompatible cache rejected by RestedXP remains `pending`
and its backup is retained; the original guide files may need reimporting
after a RestedXP version change. RestedXP still handles guide eligibility.

## Commands

Click the pocket-watch minimap button to open the command menu in the center of the screen.
With ForeverMinimap it may appear in its collected button window. Status, save,
recover, retry, check, and the starting guide run directly. Commands that need
coordinates or a guide name open a prefilled chat input. Escape closes the menu.
The button uses LibDBIcon when available, with a standalone fallback otherwise.

- `/fh`, `/fh read`, `/fh status`: show live data and backup status.
- `/fh save`: capture current preferences in memory.
- `/fh restore`: retry pending restoration.
- `/fh recover`: restore the latest snapshot, including a capture made with
  `/fh save` during this session. Login automatically selects the same snapshot.
  When no regular snapshot is available, the saved rescue copy is tried, then the optional
  local `ForeverHelperRecovery` addon. Its snapshot is an ordinary addon source
  file, so deleting SavedVariables does not remove it. Automatic fallback to this
  file is restricted to its recorded player GUID. Install it in AddOns and
  restart the client before recovery. Personal recovery data stays in the ignored
  `recovery/` directory and is not part of the shared addon source.
- `/fh check`: compare CVars with expectations in `Config.lua`.
- `/fh arrow x y`, `/fh coords x y`: move a TomTom frame from top center.
- `/fh guide Group|Guide name`: explicitly load an installed RestedXP guide.
- `/fh guide`: load the last explicitly selected guide or race's starting guide.
- `/fh apply`: compatibility alias for displaying live data.

`ForeverHelper.ReadData()` returns current profile references as `tomtom`,
`restedXP`, `restedXPTomTom`, plus `guide` and `settings`. Treat these live
references as read-only. Saved backups use independent copies.

## License

Forever Helper is licensed under the [MIT License](LICENSE).
