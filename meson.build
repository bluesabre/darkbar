# Project name, programming language and version
project (
    'com.github.bluesabre.darkbar',
    'c', 'vala',
    version: '1.0.0'
)

# GNOME module
gnome = import ('gnome')

# Translation module
i18n = import ('i18n')

# Project arguments
add_project_arguments (
    '-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name ()),
    '-DHANDY_USE_UNSTABLE_API',
    '-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
    language: 'c'
)

# Listing dependencies
dependencies = [
    dependency ('gtk+-3.0'),
    dependency ('glib-2.0'),
    dependency ('gio-unix-2.0'),
    dependency ('gee-0.8'),
    dependency ('libhandy-1', version: '>= 1.5.0'),
    dependency ('libwnck-3.0'),
    dependency ('x11'),
]

subdir ('src')

# Define executable
executable(
    meson.project_name (),
    sources,
    dependencies: dependencies,
    install: true
)

subdir ('data')
subdir ('po')

meson.add_install_script ('meson/post_install.py')
