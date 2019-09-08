package;

import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.QuadGeometry;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.Flurry;

class GeometryDepth extends Flurry
{
    override function onConfig(_config : FlurryConfig) : FlurryConfig
    {
        _config.window.title  = 'System Tests';
        _config.window.width  = 768;
        _config.window.height = 512;

        _config.resources.preload = PrePackaged('preload');

        return _config;
    }

    override function onReady()
    {
        var camera  = new Camera2D(display.width, display.height);
        var batcher = renderer.createBatcher({ shader : resources.get('textured', ShaderResource), camera : camera });

        new QuadGeometry({ textures : [ resources.get('tank1', ImageResource) ], batchers : [ batcher ], depth : 1 }).position.set_xy(192,  64);
        new QuadGeometry({ textures : [ resources.get('tank2', ImageResource) ], batchers : [ batcher ], depth : 0 }).position.set_xy(256, 128);
        new QuadGeometry({ textures : [ resources.get('tank3', ImageResource) ], batchers : [ batcher ], depth : 2 }).position.set_xy(320, 192);
    }
}
