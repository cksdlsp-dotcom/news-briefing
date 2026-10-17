CHAIGIDA CAPTURE10 — one-click Windows build
=========================================
1. Extract this ZIP to any small folder on H: (e.g. H:\BRON_BUILD\projects\CAPTURE10_BUILDER).
2. Double-click RUN_BUILD.cmd.
3. The first run downloads the public upstream Android-AutoScreenshot source, applies only the trial modifications, and uses the EXISTING JDK/SDK/Gradle in H:\BRON_BUILD.
4. On success, install H:\BRON_BUILD\output\CHAIGIDA_CAPTURE10_DEBUG.apk on Galaxy S24 Ultra.
5. In app press "Start · 1 second · 10 pages" or "Start · 2 seconds · 10 pages", grant Android screen-sharing consent, switch to a capture-permitted reader view within 5 seconds, manually turn pages. It stops after 10 different images.
6. Test images: Pictures/CHAIGIDA_Test10/<session timestamp>/0001.png ... 0010.png.

IMPORTANT: no DRM/FLAG_SECURE bypass, and Android may block protected eBook screens.
Close other apps and test using a normal, capture-permitted image/document first.
A status-bar clock change alone should not count as a new page. Very quick page turns can still skip pages; inspect output before expanding beyond ten pages.
No guarantee of successful device behavior until locally built and tested.
The upstream has no explicit repository license: this package contains build scripts and patches, NOT a redistributed copy of its source.
This is a personal ten-page experiment, not a released product.
Run this only on your own Windows machine with the preexisting H:\BRON_BUILD environment.
