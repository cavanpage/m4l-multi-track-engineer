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
		"rect" : [ 100.0, 100.0, 700.0, 430.0 ],
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
		"description" : "Spoke Identity — Phase 1. Reads track name, color, category. Renders visual panel. Sends metadata to Python server.",
		"digest" : "",
		"tags" : "spoke identity m4l multi-track-engineer phase1",
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
					"patching_rect" : [ 50.0, 40.0, 120.0, 22.0 ],
					"text" : "live.thisdevice"
				}
			},
			{
				"box" : {
					"id" : "obj-2",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 50.0, 100.0, 170.0, 22.0 ],
					"text" : "js spoke_identity.js"
				}
			},
			{
				"box" : {
					"id" : "obj-3",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 50.0, 160.0, 110.0, 22.0 ],
					"text" : "prepend parse"
				}
			},
			{
				"box" : {
					"id" : "obj-4",
					"maxclass" : "jsui",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 50.0, 220.0, 220.0, 50.0 ],
					"text" : "jsui spoke_ui.js"
				}
			},
			{
				"box" : {
					"id" : "obj-5",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 310.0, 160.0, 110.0, 22.0 ],
					"text" : "prepend meta"
				}
			},
			{
				"box" : {
					"id" : "obj-6",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 1,
					"outlettype" : [ "" ],
					"patching_rect" : [ 310.0, 220.0, 160.0, 22.0 ],
					"text" : "node.script bridge.js"
				}
			},
			{
				"box" : {
					"id" : "obj-7",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 0,
					"outlettype" : [ ],
					"patching_rect" : [ 50.0, 310.0, 130.0, 22.0 ],
					"text" : "print spoke_meta"
				}
			},
			{
				"box" : {
					"id" : "obj-8",
					"maxclass" : "newobj",
					"numinlets" : 1,
					"numoutlets" : 0,
					"outlettype" : [ ],
					"patching_rect" : [ 310.0, 310.0, 130.0, 22.0 ],
					"text" : "print python_ack"
				}
			},
			{
				"box" : {
					"id" : "obj-9",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 190.0, 43.0, 300.0, 20.0 ],
					"text" : "← bangs when device loads into Live"
				}
			},
			{
				"box" : {
					"id" : "obj-10",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 235.0, 103.0, 340.0, 20.0 ],
					"text" : "← reads LOM via LiveAPI; auto-watches name for renames"
				}
			},
			{
				"box" : {
					"id" : "obj-11",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 50.0, 285.0, 220.0, 20.0 ],
					"text" : "visual panel (color swatch + name + category)"
				}
			},
			{
				"box" : {
					"id" : "obj-12",
					"maxclass" : "comment",
					"numinlets" : 1,
					"numoutlets" : 0,
					"patching_rect" : [ 310.0, 285.0, 260.0, 20.0 ],
					"text" : "← WebSocket bridge to Python server (ws://localhost:8765)"
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
					"source" : [ "obj-2", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-5", 0 ],
					"source" : [ "obj-2", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-7", 0 ],
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
					"destination" : [ "obj-6", 0 ],
					"source" : [ "obj-5", 0 ]
				}
			},
			{
				"patchline" : {
					"destination" : [ "obj-8", 0 ],
					"source" : [ "obj-6", 0 ]
				}
			}
		],
		"dependency_cache" : [
			{
				"name" : "spoke_identity.js",
				"patcherrelativepath" : ".",
				"type" : "Javascript",
				"implicit" : 1
			},
			{
				"name" : "spoke_ui.js",
				"patcherrelativepath" : ".",
				"type" : "Javascript",
				"implicit" : 1
			},
			{
				"name" : "bridge.js",
				"patcherrelativepath" : ".",
				"type" : "Javascript",
				"implicit" : 1
			}
		],
		"autosave" : 0
	}
}
