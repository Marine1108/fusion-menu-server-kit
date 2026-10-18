screenshot-basic (pre-built)
============================

Other scripts use this to take screenshots of the game view: CCTV/evidence (e.g. Eyewitness), MDTs,
phone cameras. It does nothing on its own.

It lives here, outside [qb] and [addons], and server.cfg starts it by name BEFORE "ensure [qb]",
so it is always running before the scripts that need it. Keep that line above "ensure [qb]".

This copy is already built (dist/), so the server doesn't run yarn / webpack for it.
License: MIT (LICENSE). Original source: https://github.com/citizenfx/screenshot-basic
