Put QBCore scripts here (one folder per resource), e.g. qb-policejob, qb-phone.
They start automatically after the Fusion framework - no server.cfg edits needed.

Do NOT add these (Fusion replaces them): qb-core, qb-inventory, qb-target, qb-menu, qb-input,
progressbar, qb-multicharacter, qb-spawn, qb-garages, qb-shops, qb-clothing, illenium-appearance,
qb-vehiclekeys, qb-weathersync, qb-ambulancejob, qb-prison, qb-management, qb-banking, LegacyFuel.

Scripts that use PolyZone directly need the PolyZone resource in this folder too.

SUB-FOLDERS
-----------
You can organize scripts into sub-folders, e.g. [jobs]/my-police-job.
Grouping folders MUST have square brackets ([jobs], not jobs), and each resource folder
must have its fxmanifest.lua directly inside it. Folders the server cannot see are listed
in the server console at startup as "... does not have a resource manifest". See README.md section 8.

UPDATING A SCRIPT
-----------------
Drag the new version's zip onto install-script.bat (Windows) or run: bash install-script.sh new-version.zip
Your edited config.lua / locales are kept and the new ones are saved beside them as .new files.
Fusion updates never touch this folder. Change a script's settings in game: F10 > Script Configs.
