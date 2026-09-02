# Slideshow viewport cap and real screenshot completion

> Superseded by [REVISION.md](REVISION.md): owner clarified small 70%/80% and large 50%/40% limits.
- Measure the Home scroll viewport, using its width and height to select portrait (50%) or landscape (80%) card height ceilings. Window resizing must update the ceiling.
- Retain the normal card when it fits. Reflow constrained cards without reducing Dynamic Type, bounding artwork and title preview to the available space.
- Verify Large and AX5 with layout tests, SwiftLint, a normal app build, and actual simulator captures.
- Complete the existing real screenshot comparison across iPhone, iPad portrait, and iPad landscape. Record unavailable content explicitly. Do not use fixture data or PDF output.
