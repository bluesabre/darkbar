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
    public ulong timer { get; set; }
    public Thread thread { get; set; }

    public WaylandWindowListener (ulong timer) {
        Object (timer: timer);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        windows = new Gee.HashMap<ulong, WaylandWindow> ();
        try {
            thread = new Thread<int> ("thread_func", thread_func);
        } catch (ThreadError e) {
            critical("Thread failed.");
        }
    }

    int thread_func() {
        debug("Thread running...");
        while (true) {
            Thread.usleep(timer);
            List<ulong> xids = get_xid_list();
            xids.foreach((xid) => {
                if (!has_xid (xid)) {
                    add_xid (xid);
                    string class_instance_name;
                    if (get_class_instance_name (xid, out class_instance_name)) {
                        debug("Found window[%s]: %s", xid.to_string(), class_instance_name);
                        WaylandWindow window = new WaylandWindow(xid,
                            class_instance_name);
                        windows.set (xid, window);
                        window_opened (window);
                    }
                }
                //Thread.yield ();
            });
            list.foreach((xid) => {
                if (xids.index (xid) == -1) {
                    debug("Lost window[%s]", xid.to_string());
                    if (windows.has_key (xid)) {
                        WaylandWindow window;
                        windows.unset (xid, out window);
                        debug("Lost window[%s]: %s", xid.to_string(), window.get_class_instance_name ());
                        window_closed (window);
                    }
                    remove_xid (xid);
                }
                return true;
            });
        }
        return 0;
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

    public List<ulong> get_xid_list() {
        List<ulong> ids = new List<ulong> ();

        try {
            string[] spawn_args = {"xdotool", "search", "--onlyvisible",  "--sync", ".+"};
            string[] spawn_env = Environ.get ();
            string ls_stdout;
            string ls_stderr;

            Process.spawn_sync ("/",
                                spawn_args,
                                spawn_env,
                                SpawnFlags.SEARCH_PATH,
                                null,
                                out ls_stdout,
                                out ls_stderr,
                                null);

            foreach (string xid in ls_stdout.split("\n")) {
                ids.append(ulong.parse(xid));
            }

        } catch (SpawnError e) {
            critical ("Error: %s", e.message);
        }

        return ids;
    }

    public bool get_class_instance_name(ulong xid, out string class_instance_name) {
        try {
            string[] spawn_args = {"xprop", "-id", xid.to_string(),  "WM_CLASS"};
            string[] spawn_env = Environ.get ();
            string ls_stdout;
            string ls_stderr;

            Process.spawn_sync ("/",
                                spawn_args,
                                spawn_env,
                                SpawnFlags.SEARCH_PATH,
                                null,
                                out ls_stdout,
                                out ls_stderr,
                                null);

            if ("WM_CLASS(STRING)" in ls_stdout) {
                Regex r = /^.* = \"(?P<wmclass>.*)\",.*$/;
                MatchInfo info;
                if (r.match(ls_stdout, 0, out info)) {
                    class_instance_name = info.fetch_named("wmclass");
                    return true;
                }
            }

        } catch (SpawnError e) {
            critical ("Error: %s", e.message);
        }

        return false;
    }

}
