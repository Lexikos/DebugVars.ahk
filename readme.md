# TreeListView

A ListView control adapted to show a "tree" of items.

```AutoHotkey
#Include <TreeListView>

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
tlv.RemoveNode(node)
```

These methods can be used to manipulate the tree after the control is created. ListView rows will be inserted or removed as appropriate if the node is visible.

```AutoHotkey
tlv.EnableRedraw(enable)
```

Enables or disables redraw for the ListView control. Useful for speeding up batch updates.  

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

## Object Lifetime

TreeListView instances are not fully deleted until after the GUI is destroyed and all other references to the object are released.

When the GUI is destroyed, the control's `OnDestroy` method clears each node's `parent` property in order to allow the nodes to be garbage-collected. Sub-classes may override OnDestroy to clear other circular references.  

## Dynamic Nodes

It can be useful to calculate *children* on-demand with a dynamic property or meta-function. For example, if the control is being used to display the contents of an object with circular references, building the entire tree is impossible (because it is infinitely large). Instead, the children can be calculated when the control first requests them, which is typically when the user expands the parent node. Do not modify the array directly while it is being displayed by the control; use `InsertChild`, `RemoveChild` and `RemoveNode` instead.

## Acknowledgements

Several `TreeListView.LV_` methods are based on [LV_EX](https://autohotkey.com/boards/viewtopic.php?f=6&t=1256) by *just me*. 


# DebugVars

Provides a GUI for viewing and modifying properties of an object and other objects returned by those properties.

```AutoHotkey
#Include <DebugVars>

dv := new DebugVars(RootNode)
dv.Show()
```

DebugVars uses a TreeListView control with a few customizations:

  - The first column has a default fixed width.
  - The second column is resized automatically to fill all available space.
  - Nodes are expected to have a `SetValue(value)` method, which is called when a value in the second column is edited.

*RootNode* should be a node object as described for TreeListView but with the additional `SetValue(value)` method. See `DebugVars.ObjectNode.ahk` for an example implementation and `DebugVars_test.ahk` for example usage.

## Methods

```AutoHotkey
dv.Show(Options, Title)
dv.Hide()
```

Show or hide the GUI.  *Options* and *Title* are optional.

## Properties

```
dv.TLV
```

An instance of `DebugVars.Control`, which is a sub-class of `TreeListView`.

## Callbacks

```
dv.OnContextMenu := Func("MyContextMenu")

MyContextMenu(dv, node, isRightClick, x, y) {
  ...
}
```

*OnContextMenu* is called when the user right-clicks or presses AppsKey within the TreeListView control. This would typically be used to show a menu providing additional options, such as removing the node or showing a *DebugVar* GUI (see below) to edit multi-line values.

## Object Lifetime

If the script retains a reference to the object, it can show and hide the GUI at will. If the script shows the GUI and then releases its references to the object, it remains "alive" until the GUI is closed by the user.


# DebugVar

Provides a GUI for viewing and editing a value, including options for selecting the type of value (string, integer or float) and line ending type.

```AutoHotkey
#Include <DebugVar>

dv := new DebugVar()
dv.SetVar(Var)
dv.Show()
```

`Var` is an object with the following properties:

  - `name`: This is shown in the window title.
  - `value`: The initial value.
  - `type`: The initial type, which can be one of the following strings: `undefined`, `string`, `integer`, `float`.
  - `readonly`: If set to true, the value can't be changed.

`Var` can be passed directly to the constructor instead of calling *SetVar*.

## Methods

```AutoHotkey
dv.SetVar(Var)
```

*SetVar* updates the GUI to reflect the current properties of the given *Var* object. It also sets `dv.Dirty` to false and disables the *Save* button.

```AutoHotkey
dv.Show()
dv.Hide()
```

Shows or hides the GUI.

```AutoHotkey
dv.Cancel()
```

Reverts any unsaved changes to the value, type or line ending type. If there are none, it hides the GUI.

## Properties

`dv.Var` contains the last object passed to the constructor or *SetVar*.

`dv.hGui` contains the HWND of the GUI.

`dv.Dirty` is true if there are unsaved changes.

## Types

The GUI shows a drop-down-list for the type of the value. The contents of this list update automatically to reflect what is valid for the current value.

As the behaviour of the GUI is based around the capabilities of AutoHotkey's debugger engine, `undefined` is valid only as an initial type (FYI). The type or value must be changed before the value can be saved.

The *Save* button is made default (activated by `Enter`) only when the type is `integer` or `float`. To enter a new line with the Enter key the user must first change the type to `string`, either via the drop-down or by making the value non-numeric. Pasting a multi-line value also works.

## Callbacks

```AutoHotkey
dv.OnSave := Func("MySave")

MySave(dv, value, type) {
  ...
}
```

Called when the user clicks the *Save* button. If the function returns false/nothing, `dv.SetVar(dv.Var)` is called automatically. If the value is saved successfully, the function should either update `dv.Var` and return false/nothing, or call `dv.SetVar()` with a new or updated *Var* object and return true.

```AutoHotkey
dv.OnDirty := Func("MyDirty")

MyDirty(dv) {
  ...
}
```

Called when the user first changes the value, type or line ending type. If the function returns false/nothing, `dv.Dirty` is set to true, the *Save* button is enabled and the GUI title is updated with the "(modified)" suffix. *OnDirty* is not called if `dv.Dirty` is already true.

```AutoHotkey
dv.OnCancel := Func("MyCancel")

MyCancel(dv) {
  ...
}
```

Called when the user presses Escape after making a modification. If the function returns false/nothing, `dv.SetVar(dv.Var)` is called automatically -- this reverts the value and reset `dv.Dirty` to false.

## Misc

The *Save* button is enabled only after changing the value, type or line ending type.

The GUI can be resized. If the initial type is `integer` or `float` the GUI defaults to showing only one row.

Line-ending options are enabled only when the value contains a line ending.

Mixed line-endings are not supported. The default is CR+LF if the initial value contains any, otherwise just LF.

## Object Lifetime

If the script retains a reference to the object, it can show and hide the GUI at will. If the script shows the GUI and then releases its references to the object, it remains "alive" until the GUI is closed by the user.