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

public class WaylandWindowListener : GLib.Object {

    public signal void window_opened (WaylandWindow window);
    public signal void window_closed (WaylandWindow window);

    public Gee.HashSet<ulong> list { get; set; }
    public Gee.HashMap<ulong, WaylandWindow> windows { get; set; }
    public uint interval { get; set; }

    public WaylandWindowListener (uint interval) {
        Object (interval: interval);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        windows = new Gee.HashMap<ulong, WaylandWindow> ();
        Timeout.add_seconds(interval, thread_func);
    }

    bool thread_func() {
        debug("Thread loop");
        debug("get_xid_list");
        List<ulong> xids = get_xid_list();
        debug("Got xid list");
        xids.foreach((xid) => {
            debug ("Looping xid: %s", xid.to_string());
            if (!has_xid (xid)) {
                add_xid (xid);
                string class_instance_name = null;
                if (get_class_instance_name (xid, out class_instance_name)) {
                    debug("Found window[%s]: %s", xid.to_string(), class_instance_name);
                    WaylandWindow window = new WaylandWindow(xid,
                        class_instance_name);
                    windows.set (xid, window);
                    window_opened (window);
                }
            }
        });
        debug("Checking lost windows");
        List<ulong> removals = new List<ulong> ();
        foreach (ulong xid in list) {
            if (xids.index (xid) == -1) {
                debug("Lost window[%s]", xid.to_string());
                if (windows.has_key (xid)) {
                    WaylandWindow window;
                    windows.unset (xid, out window);
                    debug("Lost window[%s]: %s", xid.to_string(), window.get_class_instance_name ());
                    window_closed (window);
                }
                //remove_xid (xid);
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

            debug("Spawning %s", string.joinv (" ", spawn_args));
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
                    debug("Found xid: %s", xid);
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
            debug ("Checking for wm_class");
            if ("WM_CLASS(STRING)" in xprop_output) {
                Regex r = /^.* = \"(?P<wmclass>.*)\",.*$/;
                MatchInfo info;
                if (r.match(xprop_output, 0, out info)) {
                    class_instance_name = info.fetch_named("wmclass");
                    debug ("Found wm_class: %s", class_instance_name);
                    return true;
                }
            }
            debug ("Failed to find wm_class");
        }

        class_instance_name = null;

        return false;
    }

}
