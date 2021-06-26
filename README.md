# Darkbar

![Screenshot](data/screenshots@1x.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:

* granite >= 6.0.0
* libhandy >= 1.2.0
* libwnck >= 3.36.0
* meson >= 0.43.0
* valac

Run `meson build` to configure the build environment. Change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `org.bluesabre.darkbar`

    sudo ninja install
    org.bluesabre.darkbar
