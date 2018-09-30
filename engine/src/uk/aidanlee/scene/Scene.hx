package uk.aidanlee.scene;

import snow.Snow;
import snow.api.Emitter;
import uk.aidanlee.resources.ResourceSystem;
import uk.aidanlee.gpu.Renderer;

using Lambda;

class Scene
{
    /**
     * Unique name of this scene.
     */
    public final name : String;

    /**
     * Access to the underlying snow app.
     * Will eventually be removed as things will be provided by the engine instead of snow.
     * This way the engine does not become dependent on snow.
     */
    final snow : Snow;

    /**
     * All child scenes.
     */
    final children : Array<Scene>;

    /**
     * Parent scene. If null then this is the root scene.
     */
    final parent : Scene;

    /**
     * Access to the engine renderer.
     */
    final renderer : Renderer;

    /**
     * Access to the engine resources.
     */
    final resources : ResourceSystem;

    /**
     * Access to the engine events bus.
     */
    final events : Emitter<Int>;

    /**
     * The currently active child. Null if no child is active.
     */
    var activeChild : Scene;

    public function new(_name : String, _snow : Snow, _parent : Scene, _renderer : Renderer, _resources : ResourceSystem, _events : Emitter<Int>)
    {
        name = _name;

        children  = [];
        snow      = _snow;
        parent    = _parent;
        renderer  = _renderer;
        resources = _resources;
        events    = _events;
    }

    @:generic public function create<T : Scene>(_scene : Class<T>, _name : String, _arguments : Array<Dynamic>)
    {
        var defaultArgs : Array<Dynamic> = [ _name, snow, this, renderer, resources, events ];
        
        children.push(Type.createInstance(_scene, defaultArgs.concat(_arguments)));
    }

    public function remove(_name : String)
    {
        //
    }

    public function set(_name : String, _enterWith : Any = null, _leaveWith : Any = null)
    {
        // If null is passed as a name that means we want to unset the active state.
        if (_name == null)
        {
            if (activeChild != null)
            {
                activeChild.onLeave(_leaveWith);
                activeChild = null;
            }

            return;
        }

        // If we are trying to set the scene which is currently active exit early.
        if (_name == activeChild.name)
        {
            return;
        }

        activeChild.onLeave(_leaveWith);
        activeChild = children.find(scene -> scene.name == _name);

        if (activeChild != null)
        {
            activeChild.onEnter(_enterWith);
        }
    }

    // #region Functions related to the FSM

    public function onCreated() {}
    public function onRemoved() {}

    public function onEnter<T>(_data : T) {}
    public function onLeave<T>(_data : T) {}

    public function onUpdate(_dt : Float)
    {
        if (activeChild != null)
        {
            activeChild.onUpdate(_dt);
        }
    }

    // #endregion

    // #region Functions for when engine events are fired

    public function onWindowEvent() {}

    public function onMouseDown()  {}
    public function onMouseUp()    {}
    public function onMouseMove()  {}
    public function onMouseWheel() {}

    public function onKeyDown()   {}
    public function onKeyUp()     {}
    public function onTextInput() {}

    public function onGamepadAxis()   {}
    public function onGamepadDown()   {}
    public function onGamepadUp()     {}
    public function onGamepadDevice() {}

    // #endregion
}
