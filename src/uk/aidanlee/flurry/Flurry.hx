package uk.aidanlee.flurry;

import uk.aidanlee.flurry.api.gpu.Renderer;
import uk.aidanlee.flurry.api.input.Input;
import uk.aidanlee.flurry.api.display.Display;
import uk.aidanlee.flurry.api.resources.ResourceSystem;
import sys.io.abstractions.IFileSystem;
import sys.io.abstractions.concrete.FileSystem;

class Flurry
{
    /**
     * Main events bus, engine components can fire events into this to communicate with each other.
     */
    public final events : FlurryEvents;

    /**
     * Abstracted access to the devices file system.
     */
    public var fileSystem (default, null) : IFileSystem;

    /**
     * User config file.
     */
    public var flurryConfig (default, null) : FlurryConfig;

    /**
     * The rendering backend of the engine.
     */
    public var renderer (default, null) : Renderer;

    /**
     * The main resource system of the engine.
     */
    public var resources (default, null) : ResourceSystem;

    /**
     * Manages the state of the keyboard, mouse, game gamepads.
     */
    public var input (default, null) : Input;

    /**
     * Manages the programs window and allows access to the mouse coordinates.
     */
    public var display (default, null) : Display;

    /**
     * If the preload parcel has been loaded.
     */
    public var loaded (default, null) : Bool;

    public function new()
    {
        events = new FlurryEvents();
    }

    public final function config()
    {
        flurryConfig = onConfig(new FlurryConfig());

        if (flurryConfig.resources.includeStdShaders)
        {
            trace('TODO : Load a default shader parcel');
        }
    }

    public final function ready()
    {
        loaded = false;
        
        // Setup core api components
        fileSystem = new FileSystem();
        renderer   = new Renderer(events.resource, events.display, flurryConfig.window, flurryConfig.renderer);
        resources  = new ResourceSystem(events.resource, fileSystem);
        input      = new Input(events.input);
        display    = new Display(events.display, events.input, flurryConfig);

        // Load the default parcel, this may contain the standard assets or user defined assets.
        // Once it has loaded the overridable onReady function is called.
        resources.createParcel('preload', flurryConfig.resources.preload, onPreloadParcelComplete, null, onPreloadParcelError).load();

        // Fire the init event once the engine has loaded all its components.
        events.init.dispatch();
    }

    public final function tick(_dt : Float)
    {
        onTick(_dt);
    }
    
    public final function update(_dt : Float)
    {
        // The resource system needs to be called periodically to process thread events.
        // If this is not called the resources loaded on separate threads won't be registered and parcel callbacks won't be invoked.
        resources.update();
        
        if (loaded)
        {
            input.update();

            onPreUpdate();

            events.preUpdate.dispatch();
        }

        // Pre-draw
        renderer.preRender();

        // Our game specific logic, only do it if our default parcel has loaded.
        if (loaded)
        {
            onUpdate(_dt);

            events.update.dispatch();
        }

        // Render and present
        renderer.render();

        // Post-draw

        if (loaded)
        {
            onPostUpdate();

            events.postUpdate.dispatch();
        }

        renderer.postRender();
    }

    public final function shutdown()
    {
        events.shutdown.dispatch();

        onShutdown();

        resources.free('preload');
    }

    // Flurry functions the user can override.

    function onConfig(_config : FlurryConfig) : FlurryConfig
    {
        return _config;
    }

    function onReady()
    {
        //
    }

    function onTick(_dt : Float)
    {
        //
    }

    function onPreUpdate()
    {
        //
    }

    function onUpdate(_dt : Float)
    {
        //
    }

    function onPostUpdate()
    {
        //
    }

    function onShutdown()
    {
        //
    }

    // Functions internal to flurry's setup

    final function onPreloadParcelComplete(_)
    {
        loaded = true;

        onReady();

        events.ready.dispatch();
    }

    final function onPreloadParcelError(_error : String)
    {
        throw 'Error loading preload parcel : $_error';
    }
}
