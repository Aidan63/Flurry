package uk.aidanlee.flurry.api.gpu;

import haxe.Exception;
import haxe.ds.ArraySort;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.macros.ApiSelector;
import uk.aidanlee.flurry.api.gpu.camera.Camera.CameraOrigin;
import uk.aidanlee.flurry.api.gpu.camera.Camera.CameraNdcRange;
import uk.aidanlee.flurry.api.gpu.camera.Camera3D;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.batcher.DrawCommand;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher;
import uk.aidanlee.flurry.api.gpu.backend.IRendererBackend;
import uk.aidanlee.flurry.api.resources.ResourceEvents;
import uk.aidanlee.flurry.api.display.DisplayEvents;

class Renderer
{
    /**
     * Holds the global render state.
     */
    public var backend : IRendererBackend;

    /**
     * API backend used by the renderer.
     */
    public var api : RendererBackend;

    /**
     * Batcher manager, responsible for creating, deleteing, and sorting batchers.
     */
    final batchers : Array<Batcher>;

    /**
     * Queue of all draw commands for this frame.
     */
    final queuedCommands : Array<DrawCommand>;

    public function new(_resourceEvents : ResourceEvents, _displayEvents : DisplayEvents, _windowConfig : FlurryWindowConfig, _rendererConfig : FlurryRendererConfig)
    {
        queuedCommands = [];
        batchers       = [];
        backend        = ApiSelector.getGraphicsBackend(_resourceEvents, _displayEvents, _windowConfig, _rendererConfig);
        api            = ApiSelector.getGraphicsApi();
    }

    public function queue()
    {
        if (batchers.length > 0)
        {
            ArraySort.sort(batchers, sortBatchers);

            for (batcher in batchers)
            {
                batcher.batch(backend.queue);
            }
        }
    }

    public function submit()
    {
        backend.submit();
    }

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
     * Easily create a 2D camera with the correct backend options.
     * @param _width Width of the camera.
     * @param _height Height of the camera.
     * @return Camera2D
     */
    public function createCamera2D(_width : Int, _height : Int) : Camera2D
    {
        return new Camera2D(_width, _height, getOrigin(), getNdcRange());
    }

    /**
     * Easily create a 3D camera with the correct backend options.
     * @param _fov Vertical field of view.
     * @param _aspect Aspect ratio.
     * @param _near Near clipping.
     * @param _far Far clipping.
     * @return Camera3D
     */
    public function createCamera3D(_fov : Float, _aspect : Float, _near : Float, _far : Float) : Camera3D
    {
        return new Camera3D(_fov, _aspect, _near, _far, getOrigin(), getNdcRange());
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
            batcher.drop();
            batchers.remove(batcher);
        }
    }

    /**
     * Sort the batchers in depth order.
     * @param _a Batcher a
     * @param _b Batcher b
     * @return Int
     */
    function sortBatchers(_a : Batcher, _b : Batcher) : Int
    {
        // Sort by depth
        if (_a.depth < _b.depth) return -1;
        if (_a.depth > _b.depth) return  1;

        // Then target
        switch _a.target
        {
            case Backbuffer:
                switch _b.target
                {
                    case Backbuffer: // no op
                    case Texture(_): return 1;
                }
            case Texture(_imageA):
                switch _b.target
                {
                    case Backbuffer: return -1;
                    case Texture(_imageB):
                        if (_imageA < _imageB) return -1;
                        if (_imageA < _imageB) return  1;
                }
        }

        // Lastly shader
        if (_a.shader < _b.shader) return -1;
        if (_a.shader > _b.shader) return  1;

        return 0;
    }

    function getOrigin() return switch api {
        case Ogl3, Ogl4 : BottomLeft;
        case Dx11, Mock : TopLeft;
    }

    function getNdcRange() return switch api {
        case Ogl3 : NegativeOneToNegativeOne;
        case Ogl4, Dx11, Mock : ZeroToNegativeOne;
    }
}

class BackendNotAvailableException extends Exception
{
    public function new(_backend : RendererBackend)
    {
        super('$_backend is not available on this platform');
    }
}
