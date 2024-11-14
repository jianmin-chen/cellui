Goal: Generally speedy, out-of-the-box cross-platform reactive GUI framework. Something like React on top of a custom, graphically accelerated native interface.

Something like I figure out how to render a cross-platform DOM tree first, and then figure out how to fix layout given the tree, then figure out interactivity.

Goals:

* Cross-platform compatibility (MacOS, Linux, Windows, probably in that order) and the web.
  * Preferably target the optimal windowing framework. Provide wrapper module that wraps around GLFW, but e.g. on MacOS use NSWindow and Metal. Not sure what this looks like right now.
* Has a set of primitives (rectangle, text, image) -> set of useful widgets (input, button, scrollbar) that maybe could have actual listeners/state attached to them. Everything is based upon a default `View` interface.
* Flexbox style layout, should be flexible enough for implementing layouts on top of it though. Not sure what this looks like right now.
* Scheduler for scheduling appropriate renders. Not sure what this looks like right now.
* Accessibility. Not sure what this looks like right now.

Dependencies right now, would love to get rid of some of these:

* GLFW
* Glad
* FreeType for creating texture atlases for text, Harfbuzz for shaping text
* stb_image utilities (`stb_image.h`)

I'd keep Zig libraries in `modules` - able to be used as a dependency by other Zig programs. Everything in `src` is dependent on the contents of `src` or doesn't have a use case isn't well fleshed out for general use case outside the library.

A few more things are needed at the very least for this to be serious:

* A scheduler. Right now, for example, layout is done in one go. It should do a certain amount of tasks in a certain amount of time instead.