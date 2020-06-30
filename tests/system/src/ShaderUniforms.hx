package;

import uk.aidanlee.flurry.Flurry;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.api.maths.Vector4;
import uk.aidanlee.flurry.api.gpu.geometry.UniformBlob;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.QuadGeometry;
import uk.aidanlee.flurry.api.resources.Resource.ImageFrameResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;

class ShaderUniforms extends Flurry
{
    override function onConfig(_config : FlurryConfig) : FlurryConfig
    {
        _config.window.title  = 'System Tests';
        _config.window.width  = 768;
        _config.window.height = 512;

        _config.resources.preload = [ 'preload', 'shaders' ];

        return _config;
    }

    override function onReady()
    {
        final u1 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Vector4(1.0, 1.0, 1.0, 1.0))
            .uniformBlob();

        final u2 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Vector4(1.0, 0.5, 0.5, 1.0))
            .uniformBlob();

        final u3 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Vector4(0.5, 0.5, 1.0, 1.0))
            .uniformBlob();

        final shader  = resources.get('colourise', ShaderResource);
        final camera  = renderer.createCamera2D(display.width, display.height);
        final batcher = renderer.createBatcher({ shader : shader, camera : camera });

        new QuadGeometry({
            texture  : resources.get('tank1', ImageFrameResource),
            batchers : [ batcher ],
            shader   : Shader(shader),
            uniforms : Uniforms([ u1 ]),
            x : 0, y : 128, width : 256, height : 256
        }).position.set_xy(  0, 128);

        new QuadGeometry({
            texture  : resources.get('tank2', ImageFrameResource),
            batchers : [ batcher ],
            shader   : Shader(shader),
            uniforms : Uniforms([ u2 ]),
            x : 256, y : 128, width : 256, height : 256
        });

        new QuadGeometry({
            texture  : resources.get('tank3', ImageFrameResource),
            batchers : [ batcher ],
            shader   : Shader(shader),
            uniforms : Uniforms([ u3 ]),
            x : 512, y : 128, width : 256, height : 256
        });
    }
}
