package uk.aidanlee.gpu;

import haxe.ds.ArraySort;
import uk.aidanlee.gpu.batcher.DrawCommand;
import uk.aidanlee.gpu.batcher.Batcher;
import uk.aidanlee.gpu.backend.IRendererBackend;
import uk.aidanlee.gpu.backend.WebGLBackend;
import uk.aidanlee.gpu.backend.NullBackend;
#if cpp
import uk.aidanlee.gpu.backend.GL45Backend;
#end
#if windows
import uk.aidanlee.gpu.backend.DX11Backend;
#end

enum RequestedBackend {
    WEBGL;
    GL45;
    DX11;
    NULL;
}

/**
 * Options provided to the renderer on creation.
 */
typedef RendererOptions = {
    /**
     * The backend graphics api to use.
     */
    var api : RequestedBackend;

    /**
     * The initial width of the screen.
     */
    var width : Int;

    /**
     * The initial height of the screen.
     */
    var height : Int;

    /**
     * The DPI of the screen.
     */
    var dpi : Float;

    /**
     * Maximum number of unchanging vertices allowed in the unchanging vertex buffer.
     */
    var maxUnchangingVertices : Int;

    /**
     * Maximum number of dynamic vertices allowed in the dynamic vertex buffer.
     */
    var maxDynamicVertices : Int;

    /**
     * Optional settings for the chosen api backend.
     */
    var ?backend : Dynamic;
}

class Renderer
{
    /**
     * Holds the global render state.
     */
    public final backend : IRendererBackend;

    /**
     * Class which will store information about the previous frame.
     */
    public final stats : RendererStats;

    /**
     * API backend used by the renderer.
     */
    public final api : RequestedBackend;

    /**
     * Batcher manager, responsible for creating, deleteing, and sorting batchers.
     */
    final batchers : Array<Batcher>;

    /**
     * Queue of all draw commands for this frame.
     */
    final queuedCommands : Array<DrawCommand>;

    public function new(_options : RendererOptions)
    {
        queuedCommands = [];
        batchers       = [];
        api            = _options.api;
        stats          = new RendererStats();

        switch (api) {
            #if cpp
            case GL45:
                backend = new GL45Backend(this, _options);
                api     = GL45;
            #end

            #if windows
            case DX11:
                backend = new DX11Backend(this, _options);
                api     = DX11;
            #end

            case WEBGL:
                backend = new WebGLBackend(this, _options);
                api     = WEBGL;

            default:
                backend = new NullBackend();
                api     = NULL;
        }
    }

    public function preRender()
    {
        backend.preDraw();

        stats.reset();
    }

    /**
     * Sort and draw all the batchers.
     */
    public function render()
    {
        if (batchers.length <= 0) return;

        ArraySort.sort(batchers, sortBatchers);

        stats.totalBatchers += batchers.length;

        queuedCommands.resize(0);
        for (batcher in batchers)
        {
            batcher.batch(cast queuedCommands);
        }

        backend.uploadGeometryCommands(cast queuedCommands);
        backend.submitCommands(queuedCommands);
    }

    public function postRender()
    {
        backend.postDraw();
    }

    /**
     * Clears the display.
     */
    public function clear()
    {
        backend.clear();
    }

    /**
     * Resize the renderer.
     * @param _width  Renderer new width.
     * @param _height Renderer new height.
     */
    public function resize(_width : Int, _height : Int)
    {
        backend.resize(_width, _height);
    }

    // #region Batcher Management

    /**
     * Create and return a batcher. The returned batcher is automatically added to the renderer.
     * @param _options Batcher options.
     * @return Batcher
     */
    public function createBatcher(_options : BatcherOptions) : Batcher
    {
        var batcher = new Batcher(_options);

        batchers.push(batcher);

        return batcher;
    }

    /**
     * Add several pre-existing batchers to the renderer.
     * @param _batchers Array of batchers to add.
     */
    public function addBatcher(_batchers : Array<Batcher>)
    {
        for (batcher in _batchers)
        {
            batchers.push(batcher);
        }
    }

    /**
     * Remove several batchers from the renderer.
     * @param _batchers Array of batchers to remove.
     */
    public function removeBatcher(_batchers : Array<Batcher>)
    {
        for (batcher in _batchers)
        {
            batchers.remove(batcher);
        }
    }

    // #endregion

    /**
     * Sort the batchers in depth order.
     * @param _a Batcher a
     * @param _b Batcher b
     * @return Int
     */
    function sortBatchers(_a : Batcher, _b : Batcher) : Int
    {
        // Sort by framebuffer
        if (_a.target != null && _b.target != null)
        {
            if (_a.target.id < _b.target.id) return -1;
            if (_a.target.id > _b.target.id) return  1;
        }
        else
        {
            if (_a.target != null && _b.target == null) return  1;
            if (_a.target == null && _b.target != null) return -1;
        }

        // Then depth
        if (_a.depth < _b.depth) return -1;
        if (_a.depth > _b.depth) return  1;

        // Lastly shader
        if (_a.shader.id < _b.shader.id) return -1;
        if (_a.shader.id > _b.shader.id) return  1;

        return 0;
    }
}
