/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021 Sean Davis <sean@bluesabre.org>
 */

public class ForeignWindow : GLib.Object {

    public enum DisplayMode {
        NONE,
        SYSTEM,
        DARK,
        LIGHT
    }

    public string app_id { get; set; }
    public string icon_name { get; set; }
    public DisplayMode mode { get; set; }
    public DisplayMode system_mode { get; set; }
    public DisplayMode actual_mode { get; set; }
    public Gee.HashSet<ulong> list { get; set; }

    public ForeignWindow (string app_id, string icon_name) {
        Object (app_id: app_id, icon_name: icon_name);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        mode = ForeignWindow.DisplayMode.NONE;
        actual_mode = ForeignWindow.DisplayMode.NONE;
        system_mode = ForeignWindow.DisplayMode.DARK;
    }

    public void add_xid (ulong xid) {
        list.add (xid);
        apply ();
    }

    public void remove_xid (ulong xid) {
        list.remove (xid);
    }

    public bool has_xid (ulong xid) {
        return list.contains (xid);
    }

    public DisplayMode get_mode_from_string (string modestr) {
        switch (modestr) {
            case "none":
                return DisplayMode.NONE;
            case "system":
                return DisplayMode.SYSTEM;
            case "light":
                return DisplayMode.LIGHT;
            case "dark":
                return DisplayMode.DARK;
            default:
                return DisplayMode.NONE;
        }
    }

    public void set_mode_from_string (string modestr) {
        mode = get_mode_from_string (modestr);
        if (mode == DisplayMode.SYSTEM) {
            actual_mode = system_mode;
        } else if (mode == DisplayMode.NONE) {
            actual_mode = DisplayMode.LIGHT;
        } else {
            actual_mode = mode;
        }
        apply ();
    }

    public void set_actualmode_from_string (string modestr) {
        mode = get_mode_from_string (modestr);
    }

    public void apply () {
        foreach (ulong xid in list) {
            var modestr = "";
            if (actual_mode == DisplayMode.DARK) {
                modestr = "dark";
            }
            var cmd = "xprop -id %lu -f _GTK_THEME_VARIANT 8u -set _GTK_THEME_VARIANT '%s'".printf (xid, modestr);
            try {
                GLib.Process.spawn_command_line_async (cmd);
            } catch (GLib.SpawnError e) {
                warning ("Failed to spawn xprop: %s", e.message);
            }
        }
    }

}