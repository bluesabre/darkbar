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

    public signal void window_opened ();
    public signal void window_closed ();

    public Gee.HashSet<ulong> list { get; set; }
    public ulong timer { get; set; }
    public Thread thread { get; set; }

    public WaylandWindowListener (ulong timer) {
        Object (timer: timer);
    }

    construct {
        list = new Gee.HashSet<ulong> ();
        try {
            thread = new Thread<int> ("thread_func", thread_func);
        } catch (ThreadError e) {
            stdout.printf("Thread failed.\n");
        }
    }

    int thread_func() {
        while (true) {
            stdout.printf("Thread running.\n");
            Thread.usleep(timer);
            List<ulong> xids = get_xid_list();
            xids.foreach((xid) => {
                print("Found window: %s\n", get_class_instance_name (xid));
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
            print ("Error: %s\n", e.message);
        }

        return ids;
    }

    public string get_class_instance_name(ulong xid) {
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
                if(r.match(ls_stdout, 0, out info)) {
                    var wmclass = info.fetch_named("wmclass");
                    return wmclass;
                }
            }

        } catch (SpawnError e) {
            print ("Error: %s\n", e.message);
        }

        return "";
    }

}
