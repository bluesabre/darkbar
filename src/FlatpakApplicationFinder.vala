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

    private string[] listdir (string path) {
        string[] files = {};

        try {
            var directory = File.new_for_path (path);

            var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                var filename = file_info.get_name ();
                filename = GLib.Path.build_filename (
                    path, filename
                );
                files += filename;
            }

        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }

        return files;
    }

    public Gee.HashMap<string, DesktopAppInfo> get_appinfos () {
        Gee.HashMap<string, DesktopAppInfo> appinfos = new Gee.HashMap<string, DesktopAppInfo> ();

        string[] paths = {
            GLib.Path.build_filename(
                get_system_path (), "app"
            ),
            GLib.Path.build_filename(
                get_user_path (), "app"
            )
        };

        foreach (string path in paths) {
            string[] files = listdir (path);
            foreach (string directory in files) {
                var export = descend_app (directory);
                var applications = GLib.Path.build_filename (
                    export, "share", "applications"
                );
                string[] apps = listdir (applications);
                foreach (string filename in apps) {
                    if (filename.has_suffix (".desktop")) {
                        SandboxedApplication? sandboxed_app;
                        var appinfo = new DesktopAppInfo.from_filename (filename);
                        if (appinfo != null) {
                            sandboxed_app = new SandboxedApplication.from_app_info (appinfo);
                        } else {
                            sandboxed_app = new SandboxedApplication.from_filename_and_export_directory (filename, export);
                        }
                        if (sandboxed_app != null) {
                            appinfos[sandboxed_app.app_id] = sandboxed_app.app_info;
                        }
                    }
                }
            }
        }

        return appinfos;
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
