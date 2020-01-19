package uk.aidanlee.flurry.api.gpu.geometry;

import haxe.ds.ReadOnlyArray;
import signals.Signal1;
import signals.Signal.Signal0;
import uk.aidanlee.flurry.api.gpu.geometry.VertexBlob;
import uk.aidanlee.flurry.api.gpu.geometry.IndexBlob;
import uk.aidanlee.flurry.api.gpu.geometry.UniformBlob;
import uk.aidanlee.flurry.api.gpu.textures.SamplerState;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher;
import uk.aidanlee.flurry.api.gpu.state.ClipState;
import uk.aidanlee.flurry.api.maths.Hash;
import uk.aidanlee.flurry.api.maths.Vector3;
import uk.aidanlee.flurry.api.maths.Quaternion;
import uk.aidanlee.flurry.api.maths.Transformation;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;

using Safety;

typedef GeometryOptions = {
    var ?transform  : Transformation;
    var ?data       : GeometryData;
    var ?shader     : GeometryShader;
    var ?textures   : GeometryTextures;
    var ?depth      : Float;
    var ?clip       : ClipState;
    var ?primitive  : PrimitiveType;
    var ?batchers   : Array<Batcher>;
    var ?blend      : Blending;
}

enum GeometryData
{
    Indexed(_vertices : VertexBlob, _indices : IndexBlob);
    UnIndexed(_vertices : VertexBlob);
}

enum GeometryShader
{
    None;
    Shader(_shader : ShaderResource);
    Uniforms(_shader : ShaderResource, _uniforms : ReadOnlyArray<UniformBlob>);
}

enum GeometryTextures
{
    None;
    Textures(_textures : ReadOnlyArray<ImageResource>);
    Samplers(_textures : ReadOnlyArray<ImageResource>, _samplers : ReadOnlyArray<SamplerState>);
}

/**
 * The geometry class is the primary way of displaying visuals to the screen.
 * 
 * Geometry contains a collection of vertices which defines the shape of the geometry
 * and other rendering properties which will decide how it is drawn to the screen.
 */
class Geometry
{
    /**
     * Randomly generated ID for this geometry.
     */
    public final id : Int;

    /**
     * Signal which is dispatched when some property of this geometry is changed.
     */
    public final changed : Signal0;

    /**
     * Signal which is dispatched when the geometry is disposed of.
     */
    public final dropped : Signal1<Geometry>;

    /**
     * Transformation of this geometry.
     */
    public final transformation : Transformation;

    /**
     * The blend state for this geometry.
     */
    public final blend : Blending;

    /**
     * Clipping rectangle for this geometry. Null if none.
     */
    public final clip : ClipState;

    /**
     * Vertex data of this geometry.
     */
    public var data : GeometryData;

    /**
     * All of the images this image will provide to the shader.
     */
    public var textures (default, set) : GeometryTextures;

    inline function set_textures(_textures : GeometryTextures) : GeometryTextures {
        textures = _textures;

        changed.dispatch();

        return _textures;
    }

    /**
     * The specific shader for the geometry.
     * If null the batchers shader is used.
     */
    public var shader (default, set) : GeometryShader;

    inline function set_shader(_shader : GeometryShader) : GeometryShader {
        shader = _shader;

        changed.dispatch();

        return _shader;
    }

    /**
     * The depth of this mesh within the batcher.
     */
    public var depth (default, set) : Float;

    inline function set_depth(_depth : Float) : Float {
        if (depth != _depth)
        {
            depth = _depth;

            changed.dispatch();
        }

        return _depth;
    }

    /**
     * The primitive type of this geometry.
     */
    public var primitive (default, set) : PrimitiveType;

    inline function set_primitive(_primitive : PrimitiveType) : PrimitiveType {
        if (primitive != _primitive)
        {
            primitive = _primitive;

            changed.dispatch();
        }

        return _primitive;
    }

    /**
     * The position of the geometry.
     */
    public var position (get, never) : Vector3;

    inline function get_position() : Vector3 return transformation.position;

    /**
     * The origin of the geometry.
     */
    public var origin (get, never) : Vector3;

    inline function get_origin() : Vector3 return transformation.origin;

    /**
     * Rotation of the geometry.
     */
    public var rotation (get, never) : Quaternion;

    inline function get_rotation() : Quaternion return transformation.rotation;

    /**
     * Scale of the geometry.
     */
    public var scale (get, never) : Vector3;

    inline function get_scale() : Vector3 return transformation.scale;

    /**
     * Create a new mesh, contains no vertices and no transformation.
     */
    public function new(_options : GeometryOptions)
    {
        id = Hash.uniqueHash();

        changed        = new Signal0();
        dropped        = new Signal1<Geometry>();
        data           = _options.data;
        shader         = _options.shader    .or(None);
        clip           = _options.clip      .or(None);
        textures       = _options.textures  .or(None);
        transformation = _options.transform .or(new Transformation());
        depth          = _options.depth     .or(0);
        primitive      = _options.primitive .or(Triangles);
        blend          = _options.blend     .or(new Blending());

        // Add to batchers.
        if (_options.batchers != null)
        {
            for (batcher in _options.batchers.unsafe())
            {
                batcher.addGeometry(this);
            }
        }
    }
}