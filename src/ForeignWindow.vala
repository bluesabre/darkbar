/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2021-2022 Sean Davis <sean@bluesabre.org>
 */

public class ForeignWindow : GLib.Object {

    public enum DisplayMode {
        NONE,
        SYSTEM,
        DARK,
        LIGHT
    }

    public string app_id { get; set; }
    public string app_name { get; set; }
    public GLib.Icon icon { get; set; }
    public DisplayMode mode { get; set; }
    public DisplayMode system_mode { get; set; }
    public DisplayMode actual_mode { get; set; }
    public Gee.HashSet<ulong> list { get; set; }
    public bool sandboxed { get; set; }

    public ForeignWindow (string app_id,
                          string app_name,
                          GLib.Icon icon,
                          DisplayMode mode,
                          bool prefers_dark,
                          bool sandboxed) {
        Object (app_id: app_id,
                app_name: app_name,
                icon: icon,
                mode: mode,
                system_mode: prefers_dark ? DisplayMode.DARK : DisplayMode.LIGHT,
                sandboxed: sandboxed);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        actual_mode = ForeignWindow.DisplayMode.NONE;
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

    public bool empty () {
        return list.size == 0;
    }

    public static DisplayMode get_mode_from_string (string modestr) {
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

    public static string get_mode_string_for_mode (uint display_mode) {
        switch (display_mode) {
            case DisplayMode.NONE:
                return "none";
            case DisplayMode.SYSTEM:
                return "system";
            case DisplayMode.LIGHT:
                return "light";
            case DisplayMode.DARK:
                return "dark";
            default:
                return "none";
        }
    }

    public string get_mode_string () {
        return get_mode_string_for_mode (mode);
    }

    public void recompute_mode () {
        if (mode == DisplayMode.SYSTEM) {
            actual_mode = system_mode;
        } else {
            actual_mode = mode;
        }
        apply ();
    }

    public void set_mode_from_string (string modestr) {
        mode = get_mode_from_string (modestr);
        recompute_mode ();
    }

    public void set_actualmode_from_string (string modestr) {
        mode = get_mode_from_string (modestr);
        recompute_mode ();
    }

    public void set_system_dark_mode (bool prefers_dark) {
        if (prefers_dark) {
            system_mode = DisplayMode.DARK;
        } else {
            system_mode = DisplayMode.LIGHT;
        }
        recompute_mode ();
    }

    public void apply () {
        if (actual_mode == DisplayMode.NONE) {
            return;
        }
        foreach (ulong xid in list) {
            var modestr = "";
            if (actual_mode == DisplayMode.DARK) {
                modestr = "dark";
            }
            var xprop = "xprop";
            if (sandboxed) {
                xprop = "flatpak-spawn --host xprop";
            }
            var cmd = "%s -id %lu -f _GTK_THEME_VARIANT 8u -set _GTK_THEME_VARIANT '%s'".printf (xprop, xid, modestr);
            try {
                GLib.Process.spawn_command_line_async (cmd);
            } catch (GLib.SpawnError e) {
                warning ("Failed to spawn xprop: %s", e.message);
            }
        }
    }

}
