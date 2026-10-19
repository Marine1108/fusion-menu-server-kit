Put addon content here: vehicles, EUP / clothing packs, weapons, peds, maps / MLOs, sounds.
Everything in this folder starts automatically after a server restart.

Vehicles  - appear in the Fusion vehicle spawner by themselves (also under "Addon Vehicles").
            Edit names, prices and access in game: Admin > Vehicles.
            Tune handling in game: Admin > Handling (saves into the pack's handling.meta).
            Fix siren / lightbar / modkit ID clashes: Admin > Server > Vehicle meta (carcols) fixer.
EUP       - shows up in the appearance editor automatically. Save outfits as job uniforms in game.
Weapons   - add each weapon's spawn name under Admin > Settings > Weapons > Custom / addon weapons.

SUB-FOLDERS
-----------
You can organise packs into sub-folders, e.g. [cars]/[police]/lspd-pack.
Grouping folders MUST have square brackets ([cars], not cars), and each resource folder
must have its fxmanifest.lua directly inside it. Folders the server cannot see are listed
in the server console at startup as "... does not have a resource manifest". See README.md section 8.

UPDATING A PACK
---------------
Drag the new version's zip onto install-script.bat (Windows) or run: bash install-script.sh new-version.zip
Files you changed (e.g. a handling.meta edited in Admin > Handling) are kept, the pack's new ones saved as .new.
Fusion updates never touch this folder. After updating a vehicle pack, restart the server once before using
the handling editor or the carcols fixer on it.
