Goals:

* Cross-platform compatibility (MacOS, Linux, Windows, probably in that order) and the web.
    * Preferably target the optimal windowing framework. Provide GLFW, but e.g. on MacOS use Metal. Not sure what this looks like right now.
* Has a set of primitives (rectangles, text, images) -> set of useful widgets (inputs, buttons) that maybe could have actual listeners/state attached to them
* Flexbox style layout, should be flexible enough for implementing layouts on top of it though. Not sure what this looks like right now.

Dependencies right now, would love to dig into these at some point:

* GLFW
* Glad
* FreeType for creating texture atlases for text, Harfbuzz for shaping text, 
* stb_image utilities
