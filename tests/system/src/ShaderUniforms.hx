package;

import uk.aidanlee.flurry.api.gpu.geometry.UniformBlob.UniformBlobBuilder;
import uk.aidanlee.flurry.api.gpu.geometry.Color;
import uk.aidanlee.flurry.api.gpu.shader.Uniforms;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.gpu.camera.Camera2D;
import uk.aidanlee.flurry.api.gpu.geometry.shapes.QuadGeometry;
import uk.aidanlee.flurry.FlurryConfig;
import uk.aidanlee.flurry.Flurry;

class ShaderUniforms extends Flurry
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
        final u1 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Color(1.0, 1.0, 1.0))
            .uniformBlob();

        final u2 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Color(1.0, 0.5, 0.5))
            .uniformBlob();

        final u3 = new UniformBlobBuilder("colours")
            .addVector4('colour', new Color(0.5, 0.5, 1.0))
            .uniformBlob();

        final camera  = new Camera2D(display.width, display.height);
        final shader  = resources.get('colourise', ShaderResource);
        final batcher = renderer.createBatcher({ shader : shader, camera : camera });

        new QuadGeometry({
            textures : [ resources.get('tank1', ImageResource) ],
            batchers : [ batcher ],
            shader   : Uniforms(shader, [ u1 ]) }).position.set_xy(  0, 128);
        new QuadGeometry({
            textures : [ resources.get('tank2', ImageResource) ],
            batchers : [ batcher ],
            shader   : Uniforms(shader, [ u2 ]) }).position.set_xy(256, 128);
        new QuadGeometry({
            textures : [ resources.get('tank3', ImageResource) ],
            batchers : [ batcher ],
            shader   : Uniforms(shader, [ u3 ]) }).position.set_xy(512, 128);
    }
}
