package;

import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.QuadGeometry;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.Flurry;

class BatchingGeometry extends Flurry
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
        final camera  = new Camera2D(display.width, display.height);
        final batcher = renderer.createBatcher({ shader : resources.get('textured', ShaderResource), camera : camera });

        new QuadGeometry({
            textures : Texture([ resources.get('tank2', ImageResource) ]),
            batchers : [ batcher ],
            x : 0, y : 128, w : 256, h : 256
        });

        new QuadGeometry({
            textures : Texture([ resources.get('tank1', ImageResource) ]),
            batchers : [ batcher ],
            x : 256, y : 128, w : 256, h : 256
        });

        new QuadGeometry({
            textures : Texture([ resources.get('tank2', ImageResource) ]),
            batchers : [ batcher ],
            x : 512, y : 128, w : 256, h : 256
        });
    }
}
