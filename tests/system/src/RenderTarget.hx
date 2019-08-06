package;

import haxe.io.Bytes;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.QuadGeometry;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.Flurry;

class RenderTarget extends Flurry
{
    override function onConfig(_config : FlurryConfig) : FlurryConfig
    {
        _config.window.title  = 'System Tests';
        _config.window.width  = 768;
        _config.window.height = 512;

        _config.renderer.backend = Ogl3;

        _config.resources.preload.shaders = [
            {
                id   : 'textured',
                path : 'assets/shaders/textured.json',
                ogl3 : { fragment : 'assets/shaders/ogl3/textured.frag', vertex : 'assets/shaders/ogl3/textured.vert' },
                ogl4 : { fragment : 'assets/shaders/ogl4/textured.frag', vertex : 'assets/shaders/ogl4/textured.vert' },
                hlsl : { fragment : 'assets/shaders/hlsl/textured.hlsl', vertex : 'assets/shaders/hlsl/textured.hlsl' }
            }
        ];
        _config.resources.preload.images = [
            { id : 'tank1', path: 'assets/images/tank1.png' },
            { id : 'tank2', path: 'assets/images/tank2.png' },
            { id : 'tank3', path: 'assets/images/tank3.png' }
        ];

        return _config;
    }

    override function onReady()
    {
        var surface = new ImageResource('surface', 256, 256, Bytes.alloc(256 * 256 * 4).getData());
        resources.addResource(surface);

        var camera1  = new Camera2D(display.width, display.height);
        var camera2  = new Camera2D(256, 256);
        var batcher1 = renderer.createBatcher({ shader : resources.get('textured', ShaderResource), camera : camera1 });
        var batcher2 = renderer.createBatcher({ shader : resources.get('textured', ShaderResource), camera : camera2, target : surface });

        new QuadGeometry({ textures : [ resources.get('tank3', ImageResource) ], batchers : [ batcher2 ] });

        new QuadGeometry({ textures : [ resources.get('tank1', ImageResource) ], batchers : [ batcher1 ] }).position.set_xy(  0, 128);
        new QuadGeometry({ textures : [ resources.get('tank2', ImageResource) ], batchers : [ batcher1 ] }).position.set_xy(256, 128);
        new QuadGeometry({ textures : [ surface ], batchers : [ batcher1 ] }).position.set_xy(512, 128);
    }
}
