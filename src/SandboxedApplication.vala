/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class SandboxedApplication : GLib.Object {

    public string app_id { get; set; }
    public string filename { get; set; }
    public string export_directory { get; set; }
    public DesktopAppInfo? app_info { get; set; }

    public SandboxedApplication(string app_id, string filename, DesktopAppInfo app_info) {
        Object (app_id: app_id,
            filename: filename,
            app_info: app_info
        );
    }

    public SandboxedApplication.from_app_info (DesktopAppInfo app_info) {
        Object (
            app_id: app_info.get_id (),
            filename: app_info.filename,
            app_info: app_info
        );
    }

    public SandboxedApplication.from_filename (string filename) {
        var keyfile = new KeyFile ();
        try {
            keyfile.load_from_file (filename, KeyFileFlags.NONE);
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

}
