package uk.aidanlee.flurry;

import uk.aidanlee.flurry.api.resources.Parcel.ParcelList;

enum RendererBackend {
    OGL3;
    OGL4;
    DX11;
    NULL;
    AUTO;
}

class FlurryConfig
{
    /**
     * All the window config options.
     */
    public final window : FlurryWindowConfig;

    /**
     * All the renderer config options.
     */
    public final renderer : FlurryRendererConfig;

    /**
     * All the resource config options.
     */
    public final resources : FlurryResourceConfig;

    public function new()
    {
        window    = new FlurryWindowConfig();
        renderer  = new FlurryRendererConfig();
        resources = new FlurryResourceConfig();
    }
}

class FlurryWindowConfig
{
    /**
     * If the window should be launched in fullscreen borderless mode. (Defaults false)
     */
    public var fullscreen : Bool;

    /**
     * If the window should have vsync applied to it.
     */
    public var vsync : Bool;

    /**
     * If the window is resiable by the user. (Defaults true)
     */
    public var resizable : Bool;

    /**
     * If the window should be borderless. (Defaults false)
     */
    public var borderless : Bool;

    /**
     * The initial width of the window.
     */
    public var width : Int;

    /**
     * The initial height of the window.
     */
    public var height : Int;

    /**
     * The title of the window.
     */
    public var title : String;

    /**
     * Create a window config class with the default settings.
     */
    public function new()
    {
        fullscreen = false;
        resizable  = true;
        borderless = false;
        width      = 1280;
        height     = 720;
        title      = "Flurry";
    }
}

class FlurryRendererConfig
{
    /**
     * Force the renderer to use a specific backend.
     * If left unchanged it will attempt to auto-select the best backend for the platform.
     */
    public var backend : RendererBackend;

    /**
     * The maximum number of vertices allowed in the dynamic vertex buffer. (Defaults 1000000)
     */
    public var dynamicVertices : Int;

    /**
     * The maximum number of vertices allowed in the unchanging vertex buffer. (Defaults 100000)
     */
    public var unchangingVertices : Int;

    /**
     * The maximum number of indices allowed in the dynamic index buffer. (Defaults 1000000)
     */
    public var dynamicIndices : Int;

    /**
     * The maximum number of indices allowed in the unchanging index buffer. (Defaults 100000)
     */
    public var unchangingIndices : Int;

    /**
     * The default clear colour used by the renderer.
     */
    public final clearColour : { r : Float, g : Float, b : Float, a : Float };

    /**
     * Any extra variables which might be used by specific backends
     */
    public final extra : Dynamic;

    /**
     * Creates a new renderer config with the default settings.
     */
    public function new()
    {
        backend            = OGL3;
        dynamicVertices    = 1000000;
        unchangingVertices = 1000000;
        dynamicIndices     = 1000000;
        unchangingIndices  = 1000000;
        clearColour        = { r : 0.2, g : 0.2, b : 0.2, a : 1.0 };
        extra              = {};
    }
}

class FlurryResourceConfig
{
    /**
     * If the standard shader parcel should not be loaded. (Defaults true).
     */
    public var includeStdShaders : Bool;

    /**
     * Any resources placed into this parcel list will be loaded before the Flurry's onReady function is called.
     */
    public final preload : ParcelList;

    /**
     * Create a new resource config with the default settings.
     */
    public function new()
    {
        includeStdShaders = true;
        preload = {
            bytes   : [],
            texts   : [],
            jsons   : [],
            images  : [],
            shaders : [],
            parcels : []
        };
    }
}
