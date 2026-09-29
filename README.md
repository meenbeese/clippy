# Clippy

Yes, Clippy from Microsoft Office is back — on macOS!

---

Clippy can be moved around (drag with mouse) and be animated (right-click).

The `SpriteKit`-Framework is used to animate through Clippy's sprite map.

--- 

## First start

1. [Download Clippy for macOS](https://github.com/Cosmo/Clippy/releases/download/2.0.0/Clippy.zip) or build from source.
2. Run the application
3. Click `📎` → `Sprites` → pick an Agent

Clippy's three agents are bundled with the app and are unpacked automatically on first launch — there is nothing to unzip by hand.

## Demo

![Demo](https://github.com/Cosmo/Clippy/blob/master/Clippy.gif?raw=true)


## Build

```sh
git clone https://github.com/meenbeese/clippy.git
```

* Open project with Xcode
* Build and run the macOS target


## Add other Agents (optional)

An `*.acs` file includes all required resources (bitmaps, sounds, definitions, etc.) of an agent.
Unfortunately, this project does not support `*.acs` files, yet. But hopefully in the future — pull-requests are welcome.
 
Until then, you can extract all resources that we need from an `*.acs` with the "[MSAgent Decompiler](http://www.lebeausoftware.org/software/decompile.aspx)" by Lebeau Software.
The decompiler writes a folder holding the agent's `*.acd` file plus `Images` and `Audio` folders.

### Conversion

Decompiled agents still need to be turned into a `.agent` folder, which Clippy does for you.

1. Click `📎` → `Add Agent…`
2. Pick the folder the decompiler wrote
3. Click `📎` → `Sprites` → pick the new Agent

No external tools are involved. The sprites are made transparent, merged into a single sprite map and the sounds are re-encoded, all inside the app.

## Attributions

Inspiration was taken from:

* https://github.com/tanathos/ClippyVS (C#)
* https://github.com/smore-inc/clippy.js (JavaScript)

Graphics were created by *Microsoft*.

## Clippy: The Unauthorized Biography

Watch the Unauthorized Biography with [Steven Sinofsky](https://twitter.com/stevesi), if you're interested in Clippy's history!

[![Clippy: The Unauthorized Biography](https://img.youtube.com/vi/8bhjNvSSuLM/0.jpg)](https://www.youtube.com/watch?v=8bhjNvSSuLM)

## Contact

* Devran "Cosmo" Uenal
* Twitter: [@maccosmo](http://twitter.com/maccosmo)
