/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021 Sean Davis <sean@bluesabre.org>
 */

public class MyApp : Gtk.Application {
    public const OptionEntry[] INSTALLER_OPTIONS = {
        { "startup", 's', 0, OptionArg.NONE, out startup_mode, "Run minimized at session startup", null},
        { null }
    };

    public static bool startup_mode;

    construct {
        application_id = "org.bluesabre.darkbar";
        flags = ApplicationFlags.FLAGS_NONE;
        Intl.setlocale (LocaleCategory.ALL, "");
        add_main_option_entries (INSTALLER_OPTIONS);
    }

    public MainWindow? main_window { get; set; }

    protected override void activate () {
        if (main_window != null) {
            main_window.show_all ();
            main_window.deiconify ();
            main_window.present ();
            return;
        }

        main_window = new MainWindow (this) {
            default_height = 500,
            default_width = 400,
            title = "Darkbar"
        };

        if (!startup_mode) {
            main_window.show_all ();
        }
    }

    public static int main (string[] args) {
        return new MyApp ().run (args);
    }
}

public class MainWindow : Hdy.ApplicationWindow {

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            icon_name: "org.bluesabre.darkbar",
            title: _("Darkbar")
        );
    }

    private ListStore list_store { get; set; }
    public Gee.HashMap<string, ForeignWindow> window_map { get; set; }
    private unowned GLib.CompareDataFunc<ForeignWindow> compare_func;
    public GLib.Settings settings { get; set; }
    public bool prefers_dark { get; set; }
    public bool run_in_background { get; set; }

    public string[] ignore_apps = {
        "io.elementary.wingpanel",
        "org.bluesabre.darkbar",
        "plank"
    };

    static construct {
        Hdy.init ();
    }

    construct {

        delete_event.connect ((event) => {
            if (run_in_background) {
                hide ();
                return true;
            }
            return false;
        });

        list_store = new ListStore (typeof (ForeignWindow));
        window_map = new Gee.HashMap<string, ForeignWindow> ();
        run_in_background = get_run_at_startup ();
        resizable = false;

        var headerbar = new Hdy.HeaderBar () {
            decoration_layout = "close:",
            show_close_button = true,
            has_subtitle = false,
            title = _("Darkbar")
        };
        
        unowned Gtk.StyleContext headerbar_ctx = headerbar.get_style_context ();
        headerbar_ctx.add_class ("default-decoration");
        headerbar_ctx.add_class (Gtk.STYLE_CLASS_FLAT);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            vexpand = true
        };
        add (vbox);

        vbox.pack_start (headerbar, false, false, 0);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        var viewport = new Gtk.Viewport (null, null) {
            hexpand = true,
            vexpand = true,
            border_width = 12
        };
        scrolled.add (viewport);
        vbox.pack_start (scrolled, true, true, 0);

        vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 18) {
            vexpand = true
        };
        viewport.add (vbox);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin = 12
        };
        var img = new Gtk.Image.from_icon_name ("org.bluesabre.darkbar", Gtk.IconSize.DIALOG);
        hbox.pack_start(img, false, false, 0);

        var glabel = new Gtk.Label (_("Darkbar replaces window decorations with your preference of a dark or light theme variant. Only applications using a standard titlebar layout are supported.")) {
            wrap = true,
            wrap_mode = Pango.WrapMode.WORD
        };
        hbox.pack_start(glabel, false, false, 0);
        vbox.pack_start(hbox, false, false, 0);

        var darkbar_prefs = new Hdy.PreferencesGroup () {
            title = _("Darkbar Preferences")
        };
        vbox.pack_start (darkbar_prefs, false, false, 0);

        var listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE
        };
        var ctx = listbox.get_style_context ();
        ctx.add_class ("content");
        darkbar_prefs.add (listbox);

        hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin = 6
        };
        listbox.insert (hbox, 0);

        glabel = new Gtk.Label (_("Run in the background")) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        hbox.pack_start (glabel, true, true, 0);

        var swidget = new Gtk.Switch () {
            active = run_in_background
        };
        swidget.notify["active"].connect (() => {
            if (!set_run_at_startup (swidget.active)) {
                swidget.active = !swidget.active;
            }
            run_in_background = swidget.active;
        });
        hbox.pack_start (swidget, false, false, 0);

        var app_prefs = new Hdy.PreferencesGroup () {
            title = _("Active Applications")
        };
        vbox.pack_start (app_prefs, true, true, 0);

        listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE
        };
        ctx = listbox.get_style_context ();
        ctx.add_class ("content");
        app_prefs.add (listbox);
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
            combo.append ("none", _("None"));
            combo.append ("system", _("Follow System Theme"));
            combo.append ("light", _("Light"));
            combo.append ("dark", _("Dark"));
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

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = prefers_dark = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = prefers_dark = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
            update_windows ();
        });

        var screen = Wnck.Screen.get_default ();
        screen.window_opened.connect ((window) => {
            ulong xid = window.get_xid ();
            unowned string app_id = window.get_class_instance_name ();

            if (app_id in ignore_apps) {
                return;
            }

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
                if (window_map[app_id].empty ()) {
                    uint pos = 0;
                    if (list_store.find (window_map[app_id], out pos)) {
                        list_store.remove (pos);
                    }
                    window_map.unset (app_id);
                }
            }
        });

    }

    private string? find_app_info (string app_id) {
        var apps = new Gee.HashMap<string, uint> ();
        List<AppInfo> app_infos = AppInfo.get_all ();
        foreach (AppInfo app_info in app_infos) {
            var score = 0;
            var id = app_info.get_id ();
            if (id.has_suffix (".desktop")) {
                var desktop_id = id.dup ();
                id = id.substring(0, id.length - 8);
                if (id.down () == app_id) {
                    return desktop_id;
                }

                var idx = id.index_of (".");
                if (idx != -1) {
                    // RDN, break it apart and traverse in reverse
                    id = id.substring(idx + 1);
                    var subids = id.down ().split (".");
                    for (var i = subids.length - 1; i >= 0; i--) {
                        var subid = subids[i];
                        if (subid == app_id) {
                            apps[desktop_id] = score;
                            break;
                        }
                        score++;
                    }
                    continue;
                }
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

        if ("-" in app_id) {
            string[] sublist = app_id.split("-");
            sublist = sublist[0:sublist.length - 1];
            var sub_app_id = string.joinv ("-", sublist);
            return find_app_info (sub_app_id);
        }
        return null;
    }

    private DesktopAppInfo? get_app_info (string app_id) {
        var app_info = new DesktopAppInfo (app_id + ".desktop");
        if (app_info == null) {
            string? desktop_app_id = find_app_info (app_id);
            if (desktop_app_id != null) {
                app_info = new DesktopAppInfo (desktop_app_id);
            }
        }
        return app_info;
    }

    public void append (string app_id) {
        var app_info = get_app_info (app_id);
        string? icon_name = null;
        var app_name = app_id;
        if (app_info != null) {
            icon_name = app_info.get_string ("Icon");
            app_name = app_info.get_name ();
        }
        if (icon_name == null) {
            icon_name = "application-default-icon";
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

    public bool get_run_at_startup () {
        var desktop_filename = "org.bluesabre.darkbar.desktop";
        var target_filename = Environment.get_home_dir () + "/.config/autostart/" + desktop_filename;
        File file = File.new_for_path (target_filename);
        if (file.query_exists (null)) {
            return true;
        }
        return false;
    }

    public bool set_run_at_startup (bool startup) {
        var desktop_filename = "org.bluesabre.darkbar.desktop";
        var target_filename = Environment.get_home_dir () + "/.config/autostart/" + desktop_filename;
        if (startup) {
            var app_info = new DesktopAppInfo (desktop_filename);
            if (app_info != null) {
                var filename = app_info.get_filename ();
                var keyfile = new KeyFile ();
                try {
                    if (keyfile.load_from_file (filename, KeyFileFlags.NONE)) {
                        var exec = keyfile.get_string ("Desktop Entry", "Exec");
                        keyfile.set_string ("Desktop Entry", "Exec", exec + " --startup");
                        if (keyfile.save_to_file (target_filename)) {
                            return true;
                        } else {
                            warning ("Failed to save autostart file: %s", target_filename);
                        }
                    } else {
                        warning ("Failed to load desktop file: %s", filename);
                    }
                } catch (Error e) {
                    warning ("Failed to load desktop file: %s (%s)", filename, e.message);
                }
            } else {
                warning ("Could not locate desktop file: %s", desktop_filename);
            }
            return false;
        } else {
            File file = File.new_for_path (target_filename);
            if (file.query_exists (null)) {
                try {
                    if (file.delete ()) {
                        return true;
                    } else {
                        warning ("Failed to delete autostart file: %s", target_filename);
                    }
                } catch (Error e) {
                    warning ("Failed to delete autostart file: %s (%s)", target_filename, e.message);
                }
                return false;
            }
            return true;
        }
    }

}