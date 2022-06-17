/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class AppEntry : GLib.Object {

    public string app_id { get; set; }
    public string filename { get; set; }
    public string export_directory { get; set; }
    public DesktopAppInfo? app_info { get; set; }

    public AppEntry(string app_id, string filename, DesktopAppInfo app_info) {
        Object (app_id: app_id,
            filename: filename,
            app_info: app_info
        );
    }

    public AppEntry.from_app_info (DesktopAppInfo app_info) {
        Object (
            app_id: app_info.get_id (),
            filename: app_info.filename,
            app_info: app_info
        );
    }

    public AppEntry.from_filename_and_export_directory (string filename, string? export_directory) {
        var keyfile = new KeyFile ();
        try {
            keyfile.load_from_file (filename, KeyFileFlags.NONE);
            if (export_directory != null) {
                string? icon_name = keyfile.get_string ("Desktop Entry", "Icon");
                string[] sizes = {
                    "scalable", "32x32", "48x48", "64x64", "128x128", "256x256", "512x512"
                };
                string[] extensions = {
                    ".png", ".svg"
                };
                foreach (string size in sizes) {
                    foreach (string extension in extensions) {
                        string icon_filename = GLib.Path.build_filename (
                            export_directory, "share", "icons", "hicolor", size, "apps", icon_name + extension
                        );
                        File file = File.new_for_path (icon_filename);
                        if (file.query_exists (null)) {
                            keyfile.set_string ("Desktop Entry", "Icon", icon_filename);
                            break;
                        }
                    }
                }
            }
            string? binary = null;
            if (keyfile.has_key ("Desktop Entry", "TryExec")) {
                binary = keyfile.get_string ("Desktop Entry", "TryExec");
            }
            if (binary == null) {
                binary = keyfile.get_string ("Desktop Entry", "Exec");
            }
            if (binary != null) {
                if (binary.contains (" ")) {
                    binary = binary.split(" ", 2)[0];
                }
                if (binary.has_prefix ("/")) {
                    binary = "/run/host" + binary;
                    keyfile.set_string ("Desktop Entry", "Exec", binary);
                } else {
                    // ./run/host/usr/bin/guake
                    // Standard path: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
                    string[] paths = {
                        "/usr/local/sbin",
                        "/usr/local/bin",
                        "/usr/sbin",
                        "/usr/bin",
                        "/sbin",
                        "/bin",
                        "/usr/games",
                        "/usr/local/games",
                        "/snap/bin"
                    };
                    foreach (string basedir in paths) {
                        var fullpath = "/run/host" + basedir + "/" + binary;
                        File file = File.new_for_path (fullpath);
                        if (file.query_exists (null)) {
                            binary = fullpath;
                            keyfile.set_string ("Desktop Entry", "Exec", binary);
                            break;
                        }
                    }
                }
                DesktopAppInfo? appinfo = new DesktopAppInfo.from_keyfile (keyfile);
                if (appinfo != null) {
                    var app_id = Path.get_basename (filename);
                    this(app_id, filename, appinfo);
                }
            }
        } catch (Error e) {
            warning ("Keyfile Processing Error: " + e.message);
        }
    }

    public AppEntry.from_filename (string filename) {
        this.from_filename_and_export_directory (filename, null);
    }

}
