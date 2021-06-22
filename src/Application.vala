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

    protected override void activate () {
        var main_window = new Gtk.ApplicationWindow (this) {
            default_height = 300,
            default_width = 300,
            title = "Darkbar"
        };

        var label = new Gtk.Label ("Now darkening all titlebars.");
        main_window.add (label);

        var screen = Wnck.Screen.get_default ();
        screen.window_opened.connect ((window) => {
            int pid = window.get_pid ();
            ulong xid = window.get_xid ();
            unowned string class_group_name = window.get_class_group_name ();
            unowned string class_instance_name = window.get_class_instance_name ();
            unowned string name = window.get_name ();
            debug ("Hello Window: %i, %lu, %s, %s, %s", pid, xid, class_group_name, class_instance_name, name);
            var cmd = "xprop -id %lu -f _GTK_THEME_VARIANT 8u -set _GTK_THEME_VARIANT dark".printf (xid);
            try {
                GLib.Process.spawn_command_line_async (cmd);
            } catch (GLib.SpawnError e) {
                warning ("Failed to spawn xprop: %s", e.message);
            }
        });

        main_window.show_all ();
    }

    public static int main (string[] args) {
        return new MyApp ().run (args);
    }
}