{
	"patcher" : {
		"fileversion" : 1,
		"appversion" : {
			"major" : 8,
			"minor" : 6,
			"revision" : 0,
			"architecture" : "x64",
			"modernui" : 1
		},
		"rect" : [ 100.0, 100.0, 660.0, 320.0 ],
		"bglocked" : 0,
		"openinpresentation" : 0,
		"default_fontsize" : 12.0,
		"default_fontface" : 0,
		"default_fontname" : "Arial",
		"gridonopen" : 1,
		"gridsize" : [ 15.0, 15.0 ],
		"gridsnaponopen" : 1,
		"objectsnaponopen" : 1,
		"statusbarvisible" : 2,
		"toolbarvisible" : 1,
		"lefttoolbarpinned" : 0,
		"toptoolbarpinned" : 0,
		"righttoolbarpinned" : 0,
		"bottomtoolbarpinned" : 0,
		"toolbars_unpinned_last_save" : 0,
		"tallnewobj" : 0,
		"boxanimatetime" : 200,
		"enablehscroll" : 1,
		"enablevscroll" : 1,
		"devicewidth" : 0.0,
		"description" : "Hub — Phase 1. Launches and manages the Python server binary. Place on Master track.",
		"digest" : "",
		"tags" : "hub m4l multi-track-engineer phase1",
		"style" : "",
		"subpatcher_template" : "",
		"assistshowspatchername" : 0,
		"boxes" : [
			{
				"box" : {
					"id" : "obj-1",
					"maxclass" : "newobj",
					"numinlets" : 0,
					"numoutlets" : 2,
					"outlettype" : [ "", "" ],
					"patching_rect" : [ 50.0, 50.0, 120.0, 22.0 ],
					"text" : "live.thisdevice"
				}
			},
			{
				"box" : {
					"id" : "obj-2",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 50.0, 110.0, 50.0, 22.0 ],
					"text" : "start"
				}
			},
			{
				"box" : {
					"id" : "obj-3",
					"maxclass" : "message",
					"numinlets" : 2,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 130.0, 110.0, 45.0, 22.0 ],
					"text" : "stop"
				}
			},
			{
				"box" : {
					"id" : "obj-4",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 50.0, 170.0, 175.0, 22.0 ],
					"text" : "node.script hub_launcher.js"
				}
			},
			{
				"box" : {
					"id" : "obj-5",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 0,
					"outlettype" : [ ],
					"patching_rect" : [ 50.0, 240.0, 120.0, 22.0 ],
					"text" : "print hub_status"
				}
			},
			{
				"box" : {
					"id" : "obj-6",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 190.0, 53.0, 380.0, 20.0 ],
					"text" : "left outlet = device loaded  |  right outlet = device removed"
				}
			},
			{
				"box" : {
					"id" : "obj-7",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 245.0, 173.0, 340.0, 20.0 ],
					"text" : "← spawns spoke_server binary via child_process (no npm)"
				}
			}
		],
		"lines" : [
			{
				"patchline" : {
					"destination" : [ "obj-2", 0 ],
					"source" : [ "obj-1", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-3", 0 ],
					"source" : [ "obj-1", 1 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-4", 0 ],
					"source" : [ "obj-2", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-4", 0 ],
					"source" : [ "obj-3", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-5", 0 ],
					"source" : [ "obj-4", 0 ]
				}
			}
		],
		"dependency_cache" : [
			{
				"name" : "hub_launcher.js",
				"patcherrelativepath" : ".",
				"type" : "Javascript",
				"implicit" : 1
			}
		],
		"autosave" : 0
	}
}
