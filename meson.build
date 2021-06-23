# project name and programming language
project('org.bluesabre.darkbar', 'vala', 'c')

# Include the translations module
i18n = import('i18n')

# Set our translation domain
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

add_project_arguments([
		'-DWNCK_I_KNOW_THIS_IS_UNSTABLE',
	],
	language: 'c',
)

# Create a new executable, list the files we want to compile, list the dependencies we need, and install
executable(
    meson.project_name(),
    'src' / 'Application.vala',
    'src' / 'ForeignWindow.vala',
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('glib-2.0'),
        dependency('gio-unix-2.0'),
        dependency('gee-0.8'),
        [dependency('libwnck-3.0'), dependency('x11')],
    ],
    install: true
)

#Translate and install our .desktop file
i18n.merge_file(
    input: 'data' / 'org.bluesabre.darkbar.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: meson.source_root() / 'po',
    type: 'desktop',
    install: true,
    install_dir: get_option('datadir') / 'applications'
)

#Translate and install our .appdata file
i18n.merge_file(
    input: 'data' / 'org.bluesabre.darkbar.appdata.xml.in',
    output: meson.project_name() + '.appdata.xml',
    po_dir: meson.source_root() / 'po',
    install: true,
    install_dir: get_option('datadir') / 'metainfo'
)

subdir('po')
