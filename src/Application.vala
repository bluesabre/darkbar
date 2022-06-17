/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2022 Sean Davis <sean@bluesabre.org>
 */

public class MyApp : Gtk.Application {
    public const OptionEntry[] INSTALLER_OPTIONS = {
        { "startup", 's', 0, OptionArg.NONE, out startup_mode, "Run minimized at session startup", null},
        { null }
    };

    public static bool startup_mode;

    construct {
        application_id = "com.github.bluesabre.darkbar";
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
            title = _("Darkbar")
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
            icon_name: "com.github.bluesabre.darkbar",
            title: _("Darkbar")
        );
    }

    private ListStore list_store { get; set; }
    public Gee.HashMap<string, ForeignWindow> window_map { get; set; }
    private unowned GLib.CompareDataFunc<ForeignWindow> compare_func;
    public GLib.Settings settings { get; set; }
    public bool prefers_dark { get; set; }
    public bool sandboxed { get; set; }
    public AppRegistry app_registry { get; set; }
    public bool run_in_background { get; set; }

    private XishWindowListener window_listener { get; set; }
    public uint window_polling_frequency { get; set; }

    private int delay = 100;
    private uint timeout_id;

    public string[] ignore_apps = {
        "io.elementary.wingpanel",
        "com.github.bluesabre.darkbar",
        "plank",
        "gnome-shell"
    };

    public string[] ignore_app_prefixes = {
        "join?",
        "crx__"
    };

    static construct {
        Hdy.init ();
    }

    construct {
        
        list_store = new ListStore (typeof (ForeignWindow));
        window_map = new Gee.HashMap<string, ForeignWindow> ();
        run_in_background = get_run_at_startup ();
        resizable = false;
        
        File file = File.new_for_path ("/var/run/host");
        if (file.query_exists (null)) {
            sandboxed = true;
        }

        app_registry = new AppRegistry (sandboxed);

        settings = new GLib.Settings ("com.github.bluesabre.darkbar");
        var gtk_settings = Gtk.Settings.get_default ();

        var headerbar = new Hdy.HeaderBar () {
            decoration_layout = gtk_settings.gtk_decoration_layout,
            show_close_button = true,
            has_subtitle = false,
            title = _("Darkbar")
        };

        gtk_settings.notify["gtk-decoration-layout"].connect (() => {
            headerbar.decoration_layout = gtk_settings.gtk_decoration_layout;
        });

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

        var hbox = get_background_switcher ();
        listbox.insert (hbox, 0);

        hbox = get_default_theme_switcher (get_default_mode_string ());
        listbox.insert (hbox, 1);

        if (is_wayland ()) {
            hbox = get_window_polling_input ();
            listbox.insert (hbox, 2);
        }

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

        listbox.bind_model ((ListModel)list_store, (obj) => {
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                margin = 6
            };

            Gtk.Image? image;
            GLib.Icon icon = ((ForeignWindow)obj).icon;

            image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.LARGE_TOOLBAR) {
                pixel_size = 24,
                tooltip_text = icon.to_string (),
                has_tooltip = true
            };

            box.pack_start (image, false, false, 0);

            var label = new Gtk.Label (((ForeignWindow)obj).app_name) {
                halign = Gtk.Align.START,
                tooltip_text = ((ForeignWindow)obj).app_id,
                has_tooltip = true,
                ellipsize = Pango.EllipsizeMode.MIDDLE
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

        var style_manager = Hdy.StyleManager.get_default();
        style_manager.color_scheme = Hdy.ColorScheme.PREFER_LIGHT;

        prefers_dark = style_manager.dark;
        style_manager.notify["dark"].connect (() => {
            prefers_dark = style_manager.dark;
            update_windows ();
        });

        if (is_wayland()) {
            window_listener = new XishWindowListener(sandboxed);

            window_listener.window_opened.connect ((window) => {
                unowned string app_id = window.get_class_instance_name ();
                if (app_id != null) {
                    ulong xid = window.get_xid ();
                    debug ("Window [%s] opened: %s", xid.to_string(), app_id);
                    add_xish_window (window);
                }
            });

            window_listener.window_closed.connect ((window) => {
                ulong xid = window.get_xid ();
                unowned string app_id = window.get_class_instance_name ();
                window_closed (xid, app_id);
            });

            window_listener.set_timeout (get_default_window_polling_frequency ());
        } else {
            var screen = Wnck.Screen.get_default ();

            screen.window_opened.connect ((window) => {
                unowned string app_id = window.get_class_instance_name ();
                if (app_id == null) {
                    if (timeout_id > 0) {
                        Source.remove(timeout_id);
                    }
                    timeout_id = Timeout.add(delay, add_all_wnck_windows);
                } else {
                    ulong xid = window.get_xid ();
                    debug ("Window [%s] opened: %s", xid.to_string(), app_id);
                    add_wnck_window (window);
                }
            });

            screen.window_closed.connect ((window) => {
                ulong xid = window.get_xid ();
                unowned string app_id = window.get_class_instance_name ();
                window_closed (xid, app_id);
            });
        }

        show.connect (() => {
            if (settings.get_boolean ("show-welcome")) {
                show_welcome_dialog ();
            }
        });

        delete_event.connect ((event) => {
            if (run_in_background) {
                hide ();
                return true;
            }
            return false;
        });

    }

    private void window_closed (ulong xid, string app_id) {
        debug ("Window [%s] closed: %s", xid.to_string(), app_id);
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
    }

    private bool is_wayland () {
        string[] spawn_env = Environ.get ();
        unowned string? wayland_display = Environ.get_variable (spawn_env, "WAYLAND_DISPLAY");
        return wayland_display != null;
    }

    private ForeignWindow.DisplayMode get_default_mode () {
        return (ForeignWindow.DisplayMode) settings.get_uint ("default-theme");
    }

    private string get_default_mode_string () {
        return ForeignWindow.get_mode_string_for_mode (get_default_mode ());
    }

    private Gtk.Box get_background_switcher () {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin = 6
        };

        var label = new Gtk.Label (_("Run in the background")) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        box.pack_start (label, true, true, 0);

        var widget = new Gtk.Switch () {
            active = run_in_background
        };
        widget.notify["active"].connect (() => {
            if (!set_run_at_startup (widget.active)) {
                widget.active = !widget.active;
            }
            run_in_background = widget.active;
        });
        box.pack_start (widget, false, false, 0);

        box.show_all ();

        return box;
    }

    private Gtk.Box get_default_theme_switcher (string? active_id) {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin = 6
        };

        var label = new Gtk.Label (_("Default style for new windows")) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        box.pack_start (label, true, true, 0);

        var combo = new Gtk.ComboBoxText ();
        combo.append ("none", _("None"));
        combo.append ("system", _("Follow System Theme"));
        combo.append ("light", _("Light"));
        combo.append ("dark", _("Dark"));
        combo.active_id = active_id;
        box.pack_start (combo, false, false, 0);

        combo.changed.connect (() => {
            var mode = ForeignWindow.get_mode_from_string (combo.active_id);
            settings.set_uint("default-theme", mode);
            return;
        });

        box.show_all ();

        return box;
    }

    private uint get_default_window_polling_frequency () {
        return settings.get_uint ("window-polling-frequency");
    }

    private Gtk.Box get_window_polling_input () {
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin = 6
        };

        var label = new Gtk.Label (_("Window polling frequency")) {
            hexpand = true,
            halign = Gtk.Align.START
        };
        box.pack_start (label, true, true, 0);

        var spin = new Gtk.SpinButton.with_range (1.0, 60.0, 1.0);
        spin.set_value (get_default_window_polling_frequency ());
        box.pack_start (spin, false, false, 0);

        spin.changed.connect (() => {
            var timeout = (uint)spin.value;
            settings.set_uint("window-polling-frequency", timeout);
            window_listener.set_timeout (timeout);
            return;
        });

        box.show_all ();

        return box;
    }

    private bool add_all_wnck_windows () {
        var screen = Wnck.Screen.get_default ();
        unowned List<Wnck.Window> windows = screen.get_windows ();
        foreach (Wnck.Window window in windows) {
            add_wnck_window (window);
        }
        return Source.REMOVE;
    }

    private void add_wnck_window (Wnck.Window window) {
        ulong xid = window.get_xid ();
        unowned string app_id = window.get_class_instance_name ();
        add_window (xid, app_id);
    }

    private void add_xish_window (XishWindow window) {
        ulong xid = window.get_xid ();
        unowned string app_id = window.get_class_instance_name ();
        add_window (xid, app_id);
    }

    private void add_window (ulong xid, string app_id) {
        if (app_id in ignore_apps) {
            return;
        }
        foreach (string prefix in ignore_app_prefixes) {
            if (app_id.has_prefix (prefix)) {
                return;
            }
        }
        if (!window_map.has_key (app_id)) {
            append (app_id);
        }
        window_map[app_id].add_xid (xid);
    }

    private void show_welcome_dialog () {
        var dialog = new Gtk.MessageDialog (
            this,
            Gtk.DialogFlags.DESTROY_WITH_PARENT,
            Gtk.MessageType.INFO,
            Gtk.ButtonsType.CLOSE,
            _("Thank you for using Darkbar!")
        );
        dialog.secondary_text = _("Darkbar replaces window decorations with your preference of a dark or light theme variant. Only applications using a standard titlebar layout are supported.");

        var custom_widget = new Gtk.CheckButton.with_label (_("Show this dialog next time."));
        custom_widget.show ();

        settings.bind ("show-welcome", custom_widget, "active", GLib.SettingsBindFlags.DEFAULT);

        dialog.response.connect (() => {
            dialog.destroy ();
        });

        var message_area = (Gtk.Box)dialog.message_area;

        message_area.add (custom_widget);
        dialog.show ();
    }

    private AppEntry? get_app_entry (string app_id) {
        return app_registry.get_appentry (app_id);
    }

    public void append (string app_id) {
        var app_entry = get_app_entry (app_id);
        GLib.Icon? icon = null;
        var defaulted = false;
        var app_name = app_id;
        if (app_entry != null) {
            icon = app_entry.get_icon ();
            app_name = app_entry.get_name ();
        }
        if (icon == null) {
            GLib.ThemedIcon themed_icon = new GLib.ThemedIcon ("application-default-icon");
            icon = (GLib.Icon)themed_icon;
        }
        ForeignWindow.DisplayMode window_mode = retrieve_window_mode (app_id);
        if (window_mode == ForeignWindow.DisplayMode.NONE) {
            window_mode = get_default_mode ();
            defaulted = true;
        }
        var window = new ForeignWindow (app_id, app_name, icon, window_mode, prefers_dark, sandboxed);
        window.recompute_mode ();
        window_map[app_id] = window;
        list_store.insert_sorted (window, this.compare_func);
        if (defaulted && window_mode != ForeignWindow.DisplayMode.NONE) {
            store_window (window);
        }
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
        var dict = new VariantDict (settings.get_value ("known-applications"));

        var variant = new Variant.uint16 ((uint16)window.mode);
        dict.insert_value (window.app_id, variant);

        settings.set_value ("known-applications", dict.end ());
    }

    public void forget_window (ForeignWindow window) {
        var dict = new VariantDict (settings.get_value ("known-applications"));

        dict.remove (window.app_id);

        settings.set_value ("known-applications", dict.end ());
    }

    public ForeignWindow.DisplayMode retrieve_window_mode (string app_id) {
        var dict = new VariantDict (settings.get_value ("known-applications"));

        var value = dict.lookup_value (app_id, VariantType.UINT16);
        if (value != null) {
            return (ForeignWindow.DisplayMode)value.get_uint16 ();
        }

        return ForeignWindow.DisplayMode.NONE;
    }

    public bool get_run_at_startup () {
        var desktop_filename = "com.github.bluesabre.darkbar.desktop";
        var target_filename = Environment.get_home_dir () + "/.config/autostart/" + desktop_filename;
        File file = File.new_for_path (target_filename);
        if (file.query_exists (null)) {
            return true;
        }
        return false;
    }

    public bool set_run_at_startup (bool startup) {
        var autostart_dir = Environment.get_home_dir () + "/.config/autostart/";
        if (GLib.DirUtils.create_with_parents (autostart_dir, 0775) == -1) {
            warning ("Failed to create autostart directory: %s", autostart_dir);
            return false;
        }

        var desktop_filename = "com.github.bluesabre.darkbar.desktop";
        var target_filename = autostart_dir + desktop_filename;
        if (startup) {
            var app_info = new DesktopAppInfo (desktop_filename);
            if (app_info != null) {
                var filename = app_info.get_filename ();
                var keyfile = new KeyFile ();
                try {
                    if (keyfile.load_from_file (filename, KeyFileFlags.NONE)) {
                        var exec = keyfile.get_string ("Desktop Entry", "Exec");
                        if (sandboxed) {
                            exec = "flatpak run com.github.bluesabre.darkbar";
                        }
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
