package uk.aidanlee.flurry;

import rx.Unit;
import rx.Subject;
import rx.subjects.Replay;
import rx.schedulers.MakeScheduler;
import uk.aidanlee.flurry.api.gpu.Renderer;
import uk.aidanlee.flurry.api.input.Input;
import uk.aidanlee.flurry.api.display.Display;
import uk.aidanlee.flurry.api.resources.ResourceSystem;
import uk.aidanlee.flurry.api.schedulers.ThreadPoolScheduler;
import uk.aidanlee.flurry.api.schedulers.MainThreadScheduler;
import sys.io.abstractions.IFileSystem;
import sys.io.abstractions.concrete.FileSystem;

using rx.Observable;
using Safety;

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

    /**
     * Scheduler to run functions on the main thread.
     * Every tick the tasks queued in this scheduler are checked to see if its time to be ran.
     */
    final mainThreadScheduler : MakeScheduler;

    /**
     * 
     */
    final taskThreadScheduler : MakeScheduler;

    public function new()
    {
        events              = new FlurryEvents();
        mainThreadScheduler = MainThreadScheduler.current;
        taskThreadScheduler = ThreadPoolScheduler.current;
    }

    public final function config()
    {
        flurryConfig = onConfig(new FlurryConfig());
    }

    public final function ready()
    {
        loaded = false;
        
        fileSystem = new FileSystem();
        renderer   = new Renderer(events.resource, events.display, flurryConfig.window, flurryConfig.renderer);
        resources  = new ResourceSystem(events.resource, fileSystem, taskThreadScheduler, mainThreadScheduler);
        input      = new Input(events.input);
        display    = new Display(events.display, events.input, flurryConfig);

        if (flurryConfig.resources.preload != null)
        {
            resources
                .load(flurryConfig.resources.preload)
                .subscribeFunction(onPreloadParcelError, onPreloadParcelComplete);
        }
        else
        {
            onPreloadParcelComplete();
        }

        // Fire the init event once the engine has loaded all its components.
        (cast events.init : Replay<Unit>).onCompleted();
    }

    public final function tick(_dt : Float)
    {
        (cast mainThreadScheduler : MainThreadScheduler).dispatch();

        onTick(_dt);
    }
    
    public final function update(_dt : Float)
    {
        if (loaded)
        {
            onPreUpdate();

            (cast events.preUpdate : Subject<Unit>).onNext(unit);
        }

        // Our game specific logic, only do it if our default parcel has loaded.
        if (loaded)
        {
            onUpdate(_dt);

            (cast events.update : Subject<Float>).onNext(_dt);
        }

        // Render and present
        renderer.render();

        // Post-draw
        if (loaded)
        {
            onPostUpdate();

            input.update();

            (cast events.postUpdate : Subject<Unit>).onNext(unit);
        }
    }

    public final function shutdown()
    {
        (cast events.preUpdate : Subject<Unit>).onNext(unit);

        onShutdown();
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

    final function onPreloadParcelComplete()
    {
        loaded = true;

        onReady();

        (cast events.ready : Replay<Unit>).onCompleted();
    }

    final function onPreloadParcelError(_error : String)
    {
        trace('Error loading preload parcel : $_error');
    }
}
