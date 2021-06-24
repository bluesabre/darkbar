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

    public ListStore list_store { get; set; }
    public Gee.HashMap<string, ForeignWindow> window_map { get; set; }
    private unowned GLib.CompareDataFunc<ForeignWindow> compare_func;
    public bool prefers_dark { get; set; }

    private string get_icon_name (string app_id) {
        var app_info = new DesktopAppInfo (app_id + ".desktop");
        var icon_name = "image-missing";
        if (app_info != null) {
            icon_name = app_info.get_string ("Icon");
        }
        return icon_name;
    }

    public void append (string app_id) {
        var window = new ForeignWindow (app_id, get_icon_name (app_id), prefers_dark);
        window_map[app_id] = window;
        list_store.insert_sorted (window, this.compare_func);
    }

    public void update_windows () {
        foreach (var window in window_map.values) {
            window.set_system_dark_mode (prefers_dark);
        }
    }

    private static int window_sort_function (ForeignWindow win1, ForeignWindow win2) {
        if (win1.app_id == win2.app_id) {
            return 0;
        }
        if (win1.app_id > win2.app_id) {
            return 1;
        }
        return -1;
    }

    public void set_sort_func (GLib.CompareDataFunc<ForeignWindow> function) {
        compare_func = function;
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
        set_sort_func (window_sort_function);

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
                ((ForeignWindow)obj).set_mode_from_string (combo.active_id);
                return;
            });

            box.show_all ();

            return box;
        });

        listbox.show_all ();

        main_window.add (listbox);

        var granite_settings = Granite.Settings.get_default ();
        prefers_dark = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            prefers_dark = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            update_windows ();
        });

        var screen = Wnck.Screen.get_default ();
        screen.window_opened.connect ((window) => {
            ulong xid = window.get_xid ();
            unowned string app_id = window.get_class_instance_name ();

            if (!window_map.has_key (app_id)) {
                append (app_id);
            }
            window_map[app_id].add_xid (xid);
        });

        screen.window_closed.connect ((window) => {
            ulong xid = window.get_xid ();
            unowned string app_id = window.get_class_instance_name ();

            if (window_map.has_key (app_id)) {
                window_map[app_id].remove_xid (xid);
            }
        });

        main_window.show_all ();
    }

    public static int main (string[] args) {
        return new MyApp ().run (args);
    }
}