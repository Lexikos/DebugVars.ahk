# DebugVars

DebugVars is a script for AutoHotkey v1.1 which allows users to view and edit variables of other scripts while they are running.

The primary purpose of this project is to provide reusable components for use in other projects, such as for integration in various editors.  DebugVars serves as a demonstration of how to implement these components.  Any code included in this project may be freely modified and/or reused.

Before running the script, ensure that [dbgp.ahk](https://github.com/Lexikos/dbgp) is installed in your function library (Lib directory), or save it at `.\Lib\dbgp.ahk`, where `.` is the directory containing DebugVars.ahk.

To start using the script, run DebugVars.ahk.

Other running scripts and their variables and objects are shown in a tree. Click the `[+]` (plus symbol) next to an item to expand it.

DebugVars attaches to a script when it is first expanded in the tree, and detaches when DebugVars exits.  DebugVars cannot attach to a script which is running at a higher integrity level (i.e. run as admin to debug other admin scripts), or if another debugger is already connected to the script.

Currently there is an arbitrary limit of *MaxChildren* (1000) children per object.

## Quick-Edit

Enter quick-edit mode by selecting an item and then pressing Tab or left clicking in the *Value* column.

Once in quick-edit mode, the following keyboard keys can be used:

  - Escape: Revert any changes to the current item and exit quick-edit mode.
  - Enter: Confirm any changes to the current item and exit quick-edit mode.
  - Up or Shift+Tab: Save the current item and switch to the next row.
  - Down or Tab: Save the current item and switch to the previous row.

Clicking outside the edit field has the same effect as pressing Enter.

Numeric strings are converted to pure numbers automatically if and only if the previous value was a pure number. To specify the type of value, use *Inspect* instead of quick-edit.

If the selected item is an object, changing the value in quick-edit mode will replace the object with a string.

**Note:** Values longer than *ShortValueLimit* (64) characters are truncated and given the `...` suffix. Use *Inspect* to view or edit longer values.

## Inspect

Press Enter or use the context menu (see below) to inspect a value.

If the value is an object, inspecting it will open a new DebugVars window with the object as its root.

If the value is not an object, inspecting it will open a *DebugVarGui*, which can be used to view or edit multi-line values or specify the type of value (integer, float or string).

**Note:** There is an arbitrary limit on the length of data that will be retrieved. Currently it is 1MB of UTF-8 encoded string data.

## Context Menu

Right click an item in the tree for the following options.

  - **Inspect** inspects a property (see above).
  - **New window** opens a new DebugVars window with the selected node as its root.
  - **Refresh** refreshes all nodes within the window.
  - **Auto refresh** sets the timer interval for automatic refresh. 

# TreeListView

A ListView control adapted to show a "tree" of items.

```AutoHotkey
#Include TreeListView.ahk

tlv := new TreeListView(RootNode, Options, Headers, GuiName) 
```

Parameters:

  - *RootNode*: The root node of the tree.
  - *Options*: [Optional] Additional options for `Gui, Add, ListView`.
  - *Headers*: [Optional] ListView column names. If omitted, there will be two unnamed columns.
  - *GuiName*: [Optional] The name of the GUI to add the control to.

## Nodes

Every node should have the following property:

  - `values`: An array of values to show in the ListView.

Nodes which can be expanded must have the following properties:

  - `expandable`: Set to true.
  - `children`: An array of child nodes.

The control sets the following properties:

  - `level`: Indentation level, set when the node becomes visible.
  - `parent`: Parent node. This is removed when the node is removed or the control is destroyed.
  - `expanded`: Whether the node is expanded. This can also be set before adding the node to the control.

## Methods

```AutoHotkey
node := tlv.NodeFromRow(row)
row := tlv.RowFromNode(node)
```

Retrieves the ListView row of a given node or vice versa. Nodes which aren't visible within the control have no row.

```AutoHotkey
tlv.InsertChild(parent, index, child)
tlv.RemoveChild(parent, index)
```

These methods can be used to manipulate the tree after the control is created. ListView rows will be inserted or removed as appropriate if the node is visible.

```AutoHotkey
tlv.EnableRedraw(enable)
```

Enables or disables redraw for the ListView control. Useful for speeding up batch updates.

```AutoHotkey
tlv.RefreshValues(node)
```  

Updates the values displayed in the ListView for this node. Also updates the node's icon. Does not affect the node's children.

## Properties

```
tlv.MinEditColumn
tlv.MaxEditColumn
```

The first and last editable column. By default, nothing is editable.

```
tlv.ScrollPos
```

Read/write: The current position of the scrollbar.

```
tlv.FocusedNode
```

Read/write: The node which has the keyboard focus.

```
tlv.hLV
tlv.hEdit
```

The HWND of the ListView and Edit control.  The Edit control is visible only while editing a value.

```
TreeListView.HwndFrom[hwnd]
```

This can be used to find a TreeListView instance given the HWND of its ListView, Edit, or ListView header control.

## Callbacks

```
tlv.OnDoubleClick := Func("MyDoubleClick")

MyDoubleClick(tlv, node) {
  ...
}
```

*OnDoubleClick* is called when a node is double-clicked.  If not defined, the standard single-click action occurs.

## Object Lifetime

TreeListView instances are not fully deleted until after the GUI is destroyed and all other references to the object are released.

When the GUI is destroyed, the control's `OnDestroy` method clears each node's `parent` property in order to allow the nodes to be garbage-collected. Sub-classes may override OnDestroy to clear other circular references.  

## Dynamic Nodes

It can be useful to calculate *children* on-demand with a dynamic property or meta-function. For example, if the control is being used to display the contents of an object with circular references, building the entire tree is impossible (because it is infinitely large). Instead, the children can be calculated when the control first requests them, which is typically when the user expands the parent node. Do not modify the array directly while it is being displayed by the control; use `InsertChild` and `RemoveChild` instead.

The *expanded* property can be used to detect when the node is first expanded. See VarTreeObjectNode for an example. 

## Acknowledgements

Several `TreeListView.LV_` methods are based on [LV_EX](https://autohotkey.com/boards/viewtopic.php?f=6&t=1256) by *just me*. 


# VarTreeGui

Provides a GUI for viewing and modifying properties of an object and other objects returned by those properties.

```AutoHotkey
#Include VarTreeGui.ahk

vtg := new VarTreeGui(RootNode)
vtg.Show()
```

VarTreeGui uses a TreeListView control with a few customizations:

  - The first column has a default fixed width.
  - The second column is resized automatically to fill all available space.
  - Nodes are expected to have a `SetValue(value)` method, which is called when a value in the second column is edited.

*RootNode* should be a node object as described for TreeListView but with the additional `SetValue(value)` method. See `VarTreeObjectNode.ahk` for an example implementation and `VarTree_test.ahk` for example usage.

## Methods

```AutoHotkey
vtg.Show(Options, Title)
vtg.Hide()
```

Show or hide the GUI.  *Options* and *Title* are optional.

## Properties

```
vtg.TLV
```

An instance of `VarTreeGui.Control`, which is a sub-class of `TreeListView`.

## Callbacks

```
vtg.OnContextMenu := Func("MyContextMenu")

MyContextMenu(vtg, node, isRightClick, x, y) {
  ...
}
```

*OnContextMenu* is called when the user right-clicks or presses AppsKey within the TreeListView control. This would typically be used to show a menu providing additional options, such as removing the node or showing a *VarEditGui* (see below) to edit multi-line values.

## Object Lifetime

If the script retains a reference to the object, it can show and hide the GUI at will. If the script shows the GUI and then releases its references to the object, it remains "alive" until the GUI is closed by the user.


# VarEditGui

Provides a GUI for viewing and editing a value, including options for selecting the type of value (string, integer or float) and line ending type.

```AutoHotkey
#Include VarEditGui.ahk

veg := new VarEditGui()
veg.SetVar(Var)
veg.Show()
```

`Var` is an object with the following properties:

  - `name`: This is shown in the window title.
  - `value`: The initial value.
  - `type`: The initial type, which can be one of the following strings: `undefined`, `string`, `integer`, `float`.
  - `readonly`: If set to true, the value can't be changed.

`Var` can be passed directly to the constructor instead of calling *SetVar*.

## Methods

```AutoHotkey
veg.SetVar(Var)
```

*SetVar* updates the GUI to reflect the current properties of the given *Var* object. It also sets `veg.Dirty` to false and disables the *Save* button.

```AutoHotkey
veg.Show()
veg.Hide()
```

Shows or hides the GUI.

```AutoHotkey
veg.Cancel()
```

Reverts any unsaved changes to the value, type or line ending type. If there are none, it hides the GUI.

## Properties

`veg.Var` contains the last object passed to the constructor or *SetVar*.

`veg.hGui` contains the HWND of the GUI.

`veg.Dirty` is true if there are unsaved changes.

## Types

The GUI shows a drop-down-list for the type of the value. The contents of this list update automatically to reflect what is valid for the current value.

As the behaviour of the GUI is based around the capabilities of AutoHotkey's debugger engine, `undefined` is valid only as an initial type (for information only). The type or value must be changed before the value can be saved.

The *Save* button is made default (activated by `Enter`) only when the type is `integer` or `float`. To enter a new line with the Enter key the user must first change the type to `string`, either via the drop-down or by making the value non-numeric. Pasting a multi-line value also works.

## Callbacks

```AutoHotkey
veg.OnSave := Func("MySave")

MySave(veg, value, type) {
  ...
}
```

Called when the user clicks the *Save* button. If the function returns false/nothing, `veg.SetVar(veg.Var)` is called automatically. If the value is saved successfully, the function should either update `veg.Var` and return false/nothing, or call `veg.SetVar()` with a new or updated *Var* object and return true.

```AutoHotkey
veg.OnDirty := Func("MyDirty")

MyDirty(veg) {
  ...
}
```

Called when the user first changes the value, type or line ending type. If the function returns false/nothing, `veg.Dirty` is set to true, the *Save* button is enabled and the GUI title is updated with the "(modified)" suffix. *OnDirty* is not called if `veg.Dirty` is already true.

```AutoHotkey
veg.OnCancel := Func("MyCancel")

MyCancel(veg) {
  ...
}
```

Called when the user presses Escape after making a modification. If the function returns false/nothing, `veg.SetVar(veg.Var)` is called automatically -- this reverts the value and reset `veg.Dirty` to false.

## Misc

The *Save* button is enabled only after changing the value, type or line ending type.

The GUI can be resized. If the initial type is `integer` or `float` the GUI defaults to showing only one row.

Line-ending options are enabled only when the value contains a line ending.

Mixed line-endings are not supported. The default is CR+LF if the initial value contains any, otherwise just LF.

## Object Lifetime

If the script retains a reference to the object, it can show and hide the GUI at will. If the script shows the GUI and then releases its references to the object, it remains "alive" until the GUI is closed by the user.


# DebugVars

DebugVars extends VarTreeGui and VarEditGui and utilises DBGp to provide the user with a way to view and edit variables and objects of any running (uncompiled) script.

## DebugVars.ahk

DebugVars.ahk is the main script file. It contains the debugger connection logic and nodes specific to the script.

Running this file will show a DebugVarsGui with a node for each running script. Scripts which this script can't attach to (e.g. because they are running at a higher integrity level) are not shown.

## DebugVarsGui.ahk

DebugVarsGui.ahk contains the parts of the script which can be easily reused by any other debugger client script.

### DebugVarsGui

DebugVarsGui extends VarTreeGui with additional capabilities, such a context menu and refresh capability.

Nodes are expected to have some additional methods for use by the methods below.

```AutoHotkey
dv.NewWindow(node)
```
Creates a new window with *node* as its root. Nodes are expected to have a method `node.Clone()` which returns a deep copy of the node. A shallow copy is insufficient as nodes must not share children. It is sufficient to return a copy with no children and have them retrieved on request.

```AutoHotkey
dv.Refresh()
```
Refreshes the tree. Nodes are expected to have a method `node.Update(tlv)` which  updates the node and its children. If `node.values` is changed, `tlv.RefreshValues(node)` should be called to update the ListView. If the node has children, it must call *Update* for each child.

### Nodes

DebugVarsGui.ahk implements several node classes which a debugger client may need. These may be used as the root node of a DebugVarsGui or as a child node.

  - *DvPropertyNode* represents a specific property.
  - *DvContextNode* represents a context (all local vars or all global vars).
  - *Dv2ContextsNode* has two children: context 0 (locals) and context 1 (globals).

See the code for usage.

New node classes can extend *DvNodeBase*, which implements all additional methods needed by DebugVarsGui. Sub-classes which can be *expandable* must have a `node.GetChildren()` method which is called when the node is first expanded.

### DebugVarGui

DebugVarGui extends VarEditGui to save its value by sending a *property_set* command on a specific debug session.

```AutoHotkey
dv := new DebugVarGui(dbg, var)
```
*dbg* is a DBGp session. *var* is the same as for VarEditGui.
