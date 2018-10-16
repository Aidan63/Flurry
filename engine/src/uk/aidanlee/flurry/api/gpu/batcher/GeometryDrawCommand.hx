package uk.aidanlee.flurry.api.gpu.batcher;

import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Matrix;
import uk.aidanlee.flurry.api.gpu.geometry.Geometry;

class GeometryDrawCommand extends DrawCommand
{
    /**
     * All of the geometry in this command.
     */
    public final geometry : Array<Geometry>;

    inline public function new(
        _geometry   : Array<Geometry>,

        _id         : Int,
        _unchanging : Bool,
        _projection : Matrix,
        _view       : Matrix,
        _vertices   : Int,
        _viewport   : Rectangle,
        _primitive  : PrimitiveType,
        _target     : ImageResource,
        _shader     : ShaderResource,
        _textures   : Array<ImageResource>,
        _clip       : Rectangle,
        _blending   : Bool,
        _srcRGB     : BlendMode = null,
        _dstRGB     : BlendMode = null,
        _srcAlpha   : BlendMode = null,
        _dstAlpha   : BlendMode = null
    )
    {
        geometry = _geometry;

        super(_id, _unchanging, _projection, _view, _vertices, _viewport, _primitive, _target, _shader, _textures, _clip, _blending, _srcRGB, _dstRGB, _srcAlpha, _dstAlpha);
    }
}