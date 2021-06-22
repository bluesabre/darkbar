/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021 Sean Davis <sean@bluesabre.org>
 */

public class MyApp : Gtk.Application {
    public MyApp () {
        Object (
            application_id: "org.bluesabre.darkbar",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    public enum DisplayMode {
        NONE,
        SYSTEM,
        DARK,
        LIGHT
    }

    public class ForeignWindow : GLib.Object {
        public string app_id;
        public string icon_name;
        public DisplayMode mode;
        public Gee.ArrayList<ulong> list;
    }

    public ListStore list_store { get; set; }
    public Gee.HashMap<string, ForeignWindow> window_map { get; set; }

    private string get_icon_name (string app_id) {
        var app_info = new DesktopAppInfo (app_id + ".desktop");
        var icon_name = "image-missing";
        if (app_info != null) {
            icon_name = app_info.get_string ("Icon");
        }
        return icon_name;
    }

    public void append (string app_id) {
        var window = new ForeignWindow () {
            app_id = app_id,
            icon_name = get_icon_name (app_id),
            mode = DisplayMode.NONE,
            list = new Gee.ArrayList<ulong> ()
        };
        window_map[app_id] = window;
        list_store.append (window);
    }

    public void append_xid (string app_id, ulong xid) {
        ForeignWindow window = window_map[app_id];
        window.list.add (xid);
    }

    protected override void activate () {
        var main_window = new Gtk.ApplicationWindow (this) {
            default_height = 300,
            default_width = 300,
            title = "Darkbar"
        };

        list_store = new ListStore (typeof (ForeignWindow));
        window_map = new Gee.HashMap<string, ForeignWindow> ();

        var listbox = new Gtk.ListBox ();
        listbox.bind_model ((ListModel)list_store, (obj) => {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin = 6
            };

            var image = new Gtk.Image.from_icon_name (((ForeignWindow)obj).icon_name, Gtk.IconSize.BUTTON);
            box.pack_start (image, false, false, 0);

            var label = new Gtk.Label (((ForeignWindow)obj).app_id) {
                halign = Gtk.Align.START
            };
            box.pack_start (label, true, true, 0);

            var combo = new Gtk.ComboBoxText ();
            combo.append ("none", "None");
            combo.append ("system", "Follow System Theme");
            combo.append ("light", "Light");
            combo.append ("dark", "Dark");
            combo.active_id = "none";
            box.pack_start (combo, false, false, 0);

            combo.changed.connect (() => {
                switch (combo.active_id) {
                    case "none":
                        ((ForeignWindow)obj).mode = DisplayMode.NONE;
                        break;
                    case "system":
                        ((ForeignWindow)obj).mode = DisplayMode.SYSTEM;
                        break;
                    case "light":
                        ((ForeignWindow)obj).mode = DisplayMode.LIGHT;
                        break;
                    case "dark":
                        ((ForeignWindow)obj).mode = DisplayMode.DARK;
                        break;
                    default:
                        ((ForeignWindow)obj).mode = DisplayMode.NONE;
                        break;
                }
                foreach (ulong xid in ((ForeignWindow)obj).list) {
                    var cmd = "xprop -id %lu -f _GTK_THEME_VARIANT 8u -set _GTK_THEME_VARIANT %s".printf (xid, combo.active_id);
                    debug (cmd);
                    try {
                        GLib.Process.spawn_command_line_async (cmd);
                    } catch (GLib.SpawnError e) {
                        warning ("Failed to spawn xprop: %s", e.message);
                    }
                }
                return;
            });

            box.show_all ();

            return box;
        });

        listbox.show_all ();

        main_window.add (listbox);

        var screen = Wnck.Screen.get_default ();
        screen.window_opened.connect ((window) => {
            ulong xid = window.get_xid ();
            unowned string class_instance_name = window.get_class_instance_name ();

            if (!window_map.has_key (class_instance_name)) {
                append (class_instance_name);
            }
            append_xid (class_instance_name, xid);
        });

        main_window.show_all ();
    }

    public static int main (string[] args) {
        return new MyApp ().run (args);
    }
}