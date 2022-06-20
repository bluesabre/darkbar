/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class XishWindowListener : GLib.Object {

    public signal void window_opened (XishWindow window);
    public signal void window_closed (XishWindow window);

    public Gee.HashSet<ulong> list { get; set; }
    public Gee.HashMap<ulong, XishWindow> windows { get; set; }
    public bool sandboxed { get; set; }
    public uint interval { get; set; }
    private uint timeout_id;

    public XishWindowListener (bool sandboxed) {
        Object (sandboxed: sandboxed);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        windows = new Gee.HashMap<ulong, XishWindow> ();
    }

    public void set_timeout (uint timeout) {
        interval = timeout;
        if (timeout_id > 0) {
            Source.remove (timeout_id);
        }
        timeout_id = Timeout.add_seconds(interval, refresh_windows);
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

    bool refresh_windows () {
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
                    if (parsed_xid > 0) {
                        ids.append(parsed_xid);
                    }
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
