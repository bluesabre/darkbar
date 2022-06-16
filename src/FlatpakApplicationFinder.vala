/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class FlatpakApplicationFinder : GLib.Object {

    private string? getenv(string variable) {
        var spawn_env = Environ.get ();
        return Environ.get_variable (spawn_env, variable);
    }

    private string get_system_path() {
        var systemPath = getenv("FLATPAK_SYSTEM_DIR");
        if (systemPath != null)
            return systemPath;

        return GLib.Path.build_filename(
            "/", "var", "lib", "flatpak"
        );
    }

    private string get_user_path() {
        var userPath = getenv("FLATPAK_USER_DIR");
        if (userPath != null)
            return userPath;

        var userDataDir = GLib.Environment.get_user_data_dir();

        if (userDataDir == null) {
            userDataDir = GLib.Path.build_filename(
                GLib.Environment.get_home_dir(), ".local", "share"
            );
        }

        return GLib.Path.build_filename(
            userDataDir, "flatpak"
        );
    }

    private string get_config_path() {
        var configPath = getenv("FLATPAK_CONFIG_DIR");
        if (configPath != null)
            return configPath;

        configPath = GLib.Path.build_filename(
            "/", "etc", "flatpak"
        );

        return configPath;
    }

    public void get_apps() {
        // ./app/com.github.tchx84.Flatseal/x86_64/stable/09d6d0d42d1df5db4fcbd55507e8c32e134f4f6ff334eb5e63af2978db8e4e1a/export/share/applications/com.github.tchx84.Flatseal.desktop
        // ./app/com.github.tchx84.Flatseal/x86_64/stable/09d6d0d42d1df5db4fcbd55507e8c32e134f4f6ff334eb5e63af2978db8e4e1a/export/share/icons/hicolor/scalable/apps/com.github.tchx84.Flatseal.Flatpak.svg
        warning("System Path: %s", get_system_path ());

        var apps_path = GLib.Path.build_filename(
            get_system_path (), "app"
        );
        get_apps_at_path (apps_path);
    }

    private void get_apps_at_path (string path) {
        try {
            var directory = File.new_for_path (path);

            var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                var app_id = file_info.get_name ();
                stdout.printf ("%s\n", file_info.get_name ());
                var filename = GLib.Path.build_filename (
                    path, app_id
                );
                var export = descend_app (filename);
                stdout.printf ("%s\n", export);
            }

        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
    }

    private string? descend_app (string path) {
        string? arch = next_child_directory (path);
        if (arch == null) {
            return null;
        }
        string? branch = next_child_directory (arch);
        if (branch == null) {
            return null;
        }
        string? snapshot = next_child_directory (branch);
        if (snapshot == null) {
            return null;
        }
        string export = GLib.Path.build_filename(
            snapshot, "export"
        );
        return export;
    }

    private string? next_child_directory (string path) {
        try {
            var directory = File.new_for_path (path);

            var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info = enumerator.next_file ();
            if (file_info != null) {
                var filename = GLib.Path.build_filename(
                    path,
                    file_info.get_name ()
                );
                return filename;
            }
        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
        return null;
    }

}
