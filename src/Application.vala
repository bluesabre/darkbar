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

    public Gtk.ApplicationWindow? main_window { get; set; }
    public ListStore list_store { get; set; }
    public Gee.HashMap<string, ForeignWindow> window_map { get; set; }
    private unowned GLib.CompareDataFunc<ForeignWindow> compare_func;
    public GLib.Settings settings { get; set; }
    public bool prefers_dark { get; set; }

    private AppInfo? find_app_info (string app_id) {
        List<AppInfo> app_infos = AppInfo.get_all ();
        foreach (AppInfo app_info in app_infos) {
            var id = app_info.get_id ();
            if (id.has_suffix (".desktop")) {
                id = id.substring(0, id.length - 8);
                var idx = id.index_of (".");
                if (idx != -1) {
                    // RDN
                    id = id.substring(idx + 1);
                    foreach (var subid in id.down ().split (".")) {
                        if (subid == app_id) {
                            return app_info;
                        }
                    }
                    continue;
                }
                if (id.down () == app_id) {
                    return app_info;
                }
            }
        }
        return null;
    }

    private DesktopAppInfo? get_app_info (string app_id) {
        var app_info = new DesktopAppInfo (app_id + ".desktop");
        if (app_info == null) {
            app_info = (DesktopAppInfo)find_app_info (app_id);
        }
        return app_info;
    }

    public void append (string app_id) {
        var app_info = get_app_info (app_id);
        var icon_name = "image-missing";
        var app_name = app_id;
        if (app_info != null) {
            icon_name = app_info.get_string ("Icon");
            app_name = app_info.get_name ();
        }
        ForeignWindow.DisplayMode window_mode = retrieve_window_mode (app_id);
        var window = new ForeignWindow (app_id, app_name, icon_name, window_mode, prefers_dark);
        window.recompute_mode ();
        window_map[app_id] = window;
        list_store.insert_sorted (window, this.compare_func);
    }

    public void update_windows () {
        foreach (var window in window_map.values) {
            window.set_system_dark_mode (prefers_dark);
        }
    }

    private static int window_sort_function (ForeignWindow win1, ForeignWindow win2) {
        if (win1.app_name.down () == win2.app_name.down ()) {
            return 0;
        }
        if (win1.app_name.down () > win2.app_name.down ()) {
            return 1;
        }
        return -1;
    }

    public void set_sort_func (GLib.CompareDataFunc<ForeignWindow> function) {
        compare_func = function;
    }

    public void store_window (ForeignWindow window) {
        var dict = new VariantDict(settings.get_value ("known-applications"));

        var variant = new Variant.uint16 ((uint16)window.mode);
        dict.insert_value (window.app_id, variant);

        settings.set_value ("known-applications", dict.end ());
    }

    public void forget_window (ForeignWindow window) {
        var dict = new VariantDict(settings.get_value ("known-applications"));

        dict.remove (window.app_id);

        settings.set_value ("known-applications", dict.end ());
    }

    public ForeignWindow.DisplayMode retrieve_window_mode (string app_id) {
        var dict = new VariantDict(settings.get_value ("known-applications"));

        var value = dict.lookup_value (app_id, VariantType.UINT16);
        if (value != null) {
            return (ForeignWindow.DisplayMode)value.get_uint16 ();
        }

        return ForeignWindow.DisplayMode.NONE;
    }

    protected override void activate () {
        if (main_window != null) {
            main_window.show ();
            main_window.deiconify ();
            main_window.present ();
            return;
        }

        main_window = new Gtk.ApplicationWindow (this) {
            default_height = 300,
            default_width = 300,
            title = "Darkbar"
        };

        list_store = new ListStore (typeof (ForeignWindow));
        window_map = new Gee.HashMap<string, ForeignWindow> ();

        var listbox = new Gtk.ListBox ();
        set_sort_func (window_sort_function);

        settings = new GLib.Settings ("org.bluesabre.darkbar");

        listbox.bind_model ((ListModel)list_store, (obj) => {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin = 6
            };

            var image = new Gtk.Image.from_icon_name (((ForeignWindow)obj).icon_name, Gtk.IconSize.LARGE_TOOLBAR) {
                pixel_size = 24
            };
            box.pack_start (image, false, false, 0);

            var label = new Gtk.Label (((ForeignWindow)obj).app_name) {
                halign = Gtk.Align.START
            };
            box.pack_start (label, true, true, 0);

            var combo = new Gtk.ComboBoxText ();
            combo.append ("none", "None");
            combo.append ("system", "Follow System Theme");
            combo.append ("light", "Light");
            combo.append ("dark", "Dark");
            combo.active_id = ((ForeignWindow)obj).get_mode_string ();
            box.pack_start (combo, false, false, 0);

            combo.changed.connect (() => {
                ((ForeignWindow)obj).set_mode_from_string (combo.active_id);

                if (((ForeignWindow)obj).mode == ForeignWindow.DisplayMode.NONE) {
                    forget_window ((ForeignWindow)obj);
                } else {
                    store_window ((ForeignWindow)obj);
                }

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