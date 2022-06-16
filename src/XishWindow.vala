/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2022 Sean Davis <sean@bluesabre.org>
 */

public class XishWindow : GLib.Object {

    public ulong window_xid { get; set; }
    public string window_class_instance_name { get; set; }

    public XishWindow(ulong xid, string class_instance_name) {
        Object (window_xid: xid,
            window_class_instance_name: class_instance_name
        );
    }

    public ulong get_xid () {
        return window_xid;
    }

    public unowned string get_class_instance_name () {
        return window_class_instance_name;
    }

}
