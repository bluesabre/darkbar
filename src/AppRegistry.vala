/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class AppRegistry : GLib.Object {

    private Gee.HashMap<string, AppEntry> registry { get; set; }
    public bool sandboxed { get; set; }

    public AppRegistry(bool sandboxed) {
        Object (sandboxed: sandboxed);
    }

    construct {
        registry = new Gee.HashMap<string, AppEntry> ();
    }

    public string app_id_from_desktop (string id) {
        if (id.has_suffix (".desktop")) {
            var app_id = id.substring (0, id.length - 8);
            return app_id;
        }
        return id;
    }

    public void register (string id, AppEntry entry) {
        string app_id = app_id_from_desktop (id);
        registry[app_id] = entry;
    }

    public void register_sandboxed (string id, AppEntry entry) {
        string app_id = app_id_from_desktop (id);
        if (!registry.has_key (app_id)) {
            registry[app_id] = entry;
        }
    }

    private string? getenv(string variable) {
        var spawn_env = Environ.get ();
        return Environ.get_variable (spawn_env, variable);
    }

    private string get_flatpak_system_path() {
        var systemPath = getenv("FLATPAK_SYSTEM_DIR");
        if (systemPath != null)
            return systemPath;

        return GLib.Path.build_filename(
            "/", "var", "lib", "flatpak"
        );
    }

    private string get_flatpak_user_path() {
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

    private void refresh_host_apps () {
        List<AppInfo> app_infos = AppInfo.get_all ();

        foreach (AppInfo app_info in app_infos) {
            AppEntry? entry = new AppEntry.from_app_info ((DesktopAppInfo)app_info);
            if (entry != null) {
                register (entry.app_id, entry);
            }
        }
    }

    private void refresh_flatpak_host_apps () {
        try {
            var path = "/run/host/usr/share/applications";
            var directory = File.new_for_path (path);

            var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

            FileInfo info;
            while ((info = enumerator.next_file ()) != null) {
                if (info.get_file_type () != FileType.DIRECTORY) {
                    if (info.get_name ().has_suffix (".desktop")) {
                        var filename = path + "/" + info.get_name ();
                        var appinfo = new DesktopAppInfo.from_filename (filename);
                        AppEntry? sandboxed_app;
                        if (appinfo != null) {
                            sandboxed_app = new AppEntry.from_app_info (appinfo);
                        } else {
                            sandboxed_app = new AppEntry.from_filename (filename);
                        }
                        if (sandboxed_app != null) {
                            register (sandboxed_app.app_id, sandboxed_app);
                        }
                    }
                }
            }

        } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
        }
    }

    private void refresh_flatpak_apps () {
        string[] paths = {
            GLib.Path.build_filename(
                get_flatpak_system_path (), "app"
            ),
            GLib.Path.build_filename(
                get_flatpak_user_path (), "app"
            )
        };

        foreach (string path in paths) {
            string[] files = listdir (path);
            foreach (string directory in files) {
                File check_directory = File.new_for_path (directory);
                if (!check_directory.query_exists (null)) {
                    print ("Does not exist: %s\n", directory);
                    continue;
                }
                var export = get_flatpak_export_path_for_app (directory);
                var applications = GLib.Path.build_filename (
                    export, "share", "applications"
                );
                string[] apps = listdir (applications);
                foreach (string filename in apps) {
                    if (filename.has_suffix (".desktop")) {
                        AppEntry? sandboxed_app;
                        var appinfo = new DesktopAppInfo.from_filename (filename);
                        if (appinfo != null) {
                            sandboxed_app = new AppEntry.from_app_info (appinfo);
                        } else {
                            sandboxed_app = new AppEntry.from_filename_and_export_directory (filename, export);
                        }
                        if (sandboxed_app != null) {
                            register_sandboxed (sandboxed_app.app_id, sandboxed_app);
                        }
                    }
                }
            }
        }
    }

    private void refresh_apps () {
        refresh_host_apps ();
        if (sandboxed) {
            refresh_flatpak_host_apps ();
            refresh_flatpak_apps ();
        }
    }

    public Gee.HashMap<string, DesktopAppInfo> get_appinfos () {
        Gee.HashMap<string, DesktopAppInfo> appinfos = new Gee.HashMap<string, DesktopAppInfo> ();

        refresh_apps ();

        foreach (var entry in registry) {
            appinfos[entry.key] = ((AppEntry)entry.value).app_info;
        }

        return appinfos;
    }

    public AppEntry? get_appentry (string app_id) {
        if (!registry.has_key (app_id)) {
            refresh_apps ();
        }
        if (registry.has_key (app_id)) {
            return registry[app_id];
        }
        string? fuzzy_app_id = fuzzy_match_app_info (app_id);
        if (fuzzy_app_id != null) {
            return registry[fuzzy_app_id];
        }
        return null;
    }

    public DesktopAppInfo? get_appinfo (string app_id) {
        AppEntry? app_entry = get_appentry (app_id);
        if (app_entry != null) {
            return app_entry.app_info;
        }
        return null;
    }

    private string? fuzzy_match_app_info (string app_id) {
        var apps = new Gee.HashMap<string, uint> ();

        foreach (string id in registry.keys) {
            var score = 0;

            var desktop_id = id.dup ();
            if (id.down () == app_id.down ()) {
                return desktop_id;
            }

            var idx = id.index_of (".");
            if (idx != -1) {
                // RDN, break it apart and traverse in reverse
                id = id.substring (idx + 1);
                var subids = id.down ().split (".");
                for (var i = subids.length - 1; i >= 0; i--) {
                    var subid = subids[i];
                    if (subid == app_id.down ()) {
                        apps[desktop_id] = score;
                        break;
                    }
                    score++;
                }
                continue;
            }
        }

        // App with the lowest score (most accurate match) wins
        if (apps.size > 0) {
            string? best = null;
            uint best_score = 99;
            foreach (var entry in apps.entries) {
                if (entry.value < best_score) {
                    best_score = entry.value;
                    best = entry.key;
                }
            }
            return best;
        }

        if (app_id.has_prefix ("gnome-")) {
            string gnome_id = "org.gnome." + app_id.substring(6, app_id.length - 6);
            string? fuzzy_gnome_id = fuzzy_match_app_info (gnome_id);
            if (fuzzy_gnome_id != null) {
                return fuzzy_gnome_id;
            }
        }

        if ("-" in app_id) {
            string[] sublist = app_id.split ("-");
            sublist = sublist[0:sublist.length - 1];
            var sub_app_id = string.joinv ("-", sublist);
            return fuzzy_match_app_info (sub_app_id);
        }

        return null;
    }

    private string? get_flatpak_export_path_for_app (string path) {
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
