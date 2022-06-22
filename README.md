# Darkbar

![Screenshot](data/screenshots/1x.png?raw=true)

**Darkbar** replaces window decorations with your preference of a dark or light theme variant.

It allows the following settings for each application:

- None: Let the application decide
- Follow System Theme: Use the same theme as the operating system
- Light: Prefer the "light" theme variant
- Dark: Prefer the "dark" theme variant

Only applications using traditional decorations are supported. If your app is unaffected by Darkbar, the application controls its window decorations.

## Installation

### elementary OS AppCenter
<a href="https://appcenter.elementary.io/com.github.bluesabre.darkbar"><img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter" /></a>

### Flathub
<a href="https://flathub.org/apps/details/com.github.bluesabre.darkbar"><img height="50" alt="Download on Flathub" src="https://flathub.org/assets/badges/flathub-badge-en.png"/></a>

## Building

You'll need the following dependencies to build:

* libhandy >= 1.5.0
* libwnck >= 3.36.0
* meson >= 0.43.0
* valac

And you'll need the following to run Darkbar:

* xprop
* xdotool (for Wayland support)

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `com.github.bluesabre.darkbar`

    sudo ninja install
    com.github.bluesabre.darkbar

## Translations

To contribute translations, please visit [Transifex](https://www.transifex.com/bluesabreorg/darkbar) or submit a pull request.

To update the translation templates, use `ninja`

    meson build --prefix=/usr
    cd build
    ninja com.github.bluesabre.darkbar-pot
    ninja extra-pot
