package;

import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.TextResource;
import uk.aidanlee.flurry.api.importers.bmfont.BitmapFontParser;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.TextGeometry;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.Flurry;

class Text extends Flurry
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
        _config.resources.preload.images = [ { id : 'ubuntu.png', path: 'assets/fonts/ubuntu.png' } ];
        _config.resources.preload.texts  = [ { id : 'ubuntu.fnt', path: 'assets/fonts/ubuntu.fnt' } ];

        return _config;
    }

    override function onReady()
    {
        var camera  = new Camera2D(display.width, display.height);
        var batcher = renderer.createBatcher({ shader : resources.get('textured', ShaderResource), camera : camera });

        var font = BitmapFontParser.parse(resources.get('ubuntu.fnt', TextResource).content);

        new TextGeometry({
            batchers : [ batcher ],
            textures : [ resources.get('ubuntu.png', ImageResource) ],
            font     : font,
            text     : 'hello world',
            position : new Vector(32, 32)
        });

        new TextGeometry({
            batchers : [ batcher ],
            textures : [ resources.get('ubuntu.png', ImageResource) ],
            font     : font,
            text     : 'Lorem ipsum',
            position : new Vector(32, 48)
        }).scale.set_xy(2, 2);
    }
}
