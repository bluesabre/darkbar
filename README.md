# Darkbar

![Screenshot](data/screenshots/1x.png?raw=true)

**Darkbar** replaces window decorations with your preference of a dark or light theme variant.

It allows the following settings for each application:

- None: Let the application decide</li>
- Follow System Theme: Use the same theme as the operating system
- Light: Prefer the "light" theme variant
- Dark: Prefer the "dark" theme variant

Only applications using traditional decorations are supported. If your app is unaffected by Darkbar, the application controls its window decorations.

## Building, Testing, and Installation

You'll need the following dependencies:

* libhandy >= 1.5.0
* libwnck >= 3.36.0
* meson >= 0.43.0
* valac
* xprop

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.bluesabre.darkbar`

    sudo ninja install
    com.github.bluesabre.darkbar

## Translations

To contribute translations, please visit [Transifex](https://www.transifex.com/bluesabreorg/darkbar) or submit a pull request.
