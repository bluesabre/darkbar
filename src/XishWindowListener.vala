/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

/*
[bluesabre@fedora ~]$ xdotool search --onlyvisible --sync ".+"
Defaulting to search window name, class, and classname
6291477
6291466
27262979
41943461
10485763

xdotool getwindowname 41943461
GNU Image Manipulation Program

window_opened
window_closed

https://valadoc.org/glib-2.0/GLib.Process.spawn_async_with_pipes.html

*/

public class XishWindowListener : GLib.Object {

    public signal void window_opened (XishWindow window);
    public signal void window_closed (XishWindow window);

    public Gee.HashSet<ulong> list { get; set; }
    public Gee.HashMap<ulong, XishWindow> windows { get; set; }
    public uint interval { get; set; }

    private uint timeout_id;
    private int delay = 100;

    public XishWindowListener (uint interval) {
        Object (interval: interval);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        windows = new Gee.HashMap<ulong, XishWindow> ();
        if (is_wayland ()) {
            Timeout.add_seconds(interval, refresh_wayland_windows);
        } else {
            var screen = Wnck.Screen.get_default ();
            screen.window_opened.connect ((wnck_window) => {
                add_wnck_window (wnck_window, true);
            });

            screen.window_closed.connect ((wnck_window) => {
                ulong xid = wnck_window.get_xid ();
                lost_window (xid);
                remove_xid (xid);
            });
        }
    }

    private bool add_all_wnck_windows () {
        var screen = Wnck.Screen.get_default ();
        unowned List<Wnck.Window> windows = screen.get_windows ();
        foreach (Wnck.Window window in windows) {
            add_wnck_window (window, false);
        }
        return Source.REMOVE;
    }

    private void add_wnck_window (Wnck.Window window, bool rebuild) {
        ulong xid = window.get_xid ();
        if (!has_xid (xid)) {
            unowned string class_instance_name = window.get_class_instance_name ();
            if (class_instance_name != null) {
                found_window (xid, class_instance_name);
            } else if (rebuild) {
                if (timeout_id > 0) {
                    Source.remove(timeout_id);
                }
                timeout_id = Timeout.add(delay, add_all_wnck_windows);
            }
        }
    }

    private void found_window (ulong xid, string class_instance_name) {
        debug("Found window[%s]: %s", xid.to_string(), class_instance_name);
        XishWindow window = new XishWindow(xid,
            class_instance_name);
        windows.set (xid, window);
        window_opened (window);
    }

    private void lost_window (ulong xid) {
        if (windows.has_key (xid)) {
            XishWindow window;
            windows.unset (xid, out window);
            debug("Lost window[%s]: %s", xid.to_string(), window.get_class_instance_name ());
            window_closed (window);
        }
    }

    private bool is_wayland () {
        string[] spawn_env = Environ.get ();
        unowned string? wayland_display = Environ.get_variable (spawn_env, "WAYLAND_DISPLAY");
        return wayland_display != null;
    }

    bool refresh_wayland_windows () {
        List<ulong> xids = get_xid_list();
        xids.foreach((xid) => {
            if (!has_xid (xid)) {
                add_xid (xid);
                string class_instance_name = null;
                if (get_class_instance_name (xid, out class_instance_name)) {
                    found_window (xid, class_instance_name);
                }
            }
        });

        List<ulong> removals = new List<ulong> ();
        foreach (ulong xid in list) {
            if (xids.index (xid) == -1) {
                lost_window (xid);
                removals.append (xid);
            }
        }

        foreach (ulong xid in removals) {
            remove_xid (xid);
        }

        return true;
    }

    public void add_xid (ulong xid) {
        list.add (xid);
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

    private string? spawn_sync_and_return (string[] spawn_args) {
        try {
            string[] spawn_env = Environ.get ();
            string p_stdout;
            string p_stderr;
            
            Process.spawn_sync ("/",
                                spawn_args,
                                spawn_env,
                                SpawnFlags.SEARCH_PATH,
                                null,
                                out p_stdout,
                                out p_stderr,
                                null);

            return p_stdout;

        } catch (SpawnError e) {
            critical ("Failed to execute: %s", string.joinv (" ", spawn_args));
            critical ("Error: %s", e.message);
        }

        return null;
    }

    public List<ulong> get_xid_list() {
        List<ulong> ids = new List<ulong> ();

        string[] spawn_args = {"xdotool", "search", "--onlyvisible",  "--sync", ".+"};
        string? xdotool_output = spawn_sync_and_return (spawn_args);

        if (xdotool_output != null) {
            foreach (string xid in xdotool_output.split("\n")) {
                if (xid.length > 0) {
                    ulong parsed_xid = ulong.parse (xid);
                    ids.append(parsed_xid);
                }
            }
        }

        return ids;
    }

    public bool get_class_instance_name(ulong xid, out string? class_instance_name) {
        string[] spawn_args = {"xprop", "-id", xid.to_string(),  "WM_CLASS"};
        string? xprop_output = spawn_sync_and_return (spawn_args);

        if (xprop_output != null) {
            if ("WM_CLASS(STRING)" in xprop_output) {
                Regex r = /^.* = \"(?P<wmclass>.*)\",.*$/;
                MatchInfo info;
                if (r.match(xprop_output, 0, out info)) {
                    class_instance_name = info.fetch_named("wmclass");
                    return true;
                }
            }
        }

        class_instance_name = null;

        return false;
    }

}
