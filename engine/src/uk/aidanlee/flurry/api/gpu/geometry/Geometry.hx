package uk.aidanlee.flurry.api.gpu.geometry;

import snow.api.Debug.def;
import uk.aidanlee.flurry.api.gpu.batcher.Batcher;
import uk.aidanlee.flurry.api.gpu.geometry.Transformation;
import uk.aidanlee.flurry.api.maths.Hash;
import uk.aidanlee.flurry.api.maths.Vector;
import uk.aidanlee.flurry.api.maths.Rectangle;
import uk.aidanlee.flurry.api.maths.Quaternion;
import uk.aidanlee.flurry.api.resources.Resource.ShaderResource;
import uk.aidanlee.flurry.api.resources.Resource.ImageResource;

enum PrimitiveType {
    Points;
    Lines;
    LineStrip;
    Triangles;
    TriangleStrip;
}

enum abstract GeometryEvent(String) from String to String {
    var OrderProperyChanged = 'flurry-geom-ev-order-changed';
}

typedef GeometryOptions = {
    var ?vertices   : Array<Vertex>;
    var ?transform  : Transformation;
    var ?shader     : ShaderResource;
    var ?textures   : Array<ImageResource>;
    var ?depth      : Int;
    var ?immediate  : Bool;
    var ?unchanging : Bool;
    var ?color      : Color;
    var ?clip       : Rectangle;
    var ?primitive  : PrimitiveType;
    var ?batchers   : Array<Batcher>;
    var ?blend      : Blending;
}

/**
 * Geometry class, holds a set of verticies and a matrix transformation for them.
 */
class Geometry
{
    /**
     * UUID of this geometry.
     */
    public final id : Int;

    /**
     * Fires various events about the geometry.
     */
    public final events : EventBus;

    /**
     * This meshes vertices.
     */
    public final vertices : Array<Vertex>;

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
    public final clip : Rectangle;

    /**
     * ID of the texture this mesh uses.
     */
    public var textures (default, set) : Array<ImageResource>;

    inline function set_textures(_textures : Array<ImageResource>) : Array<ImageResource> {
        events.fire(OrderProperyChanged);

        return textures = _textures;
    }

    /**
     * The specific shader for the geometry.
     * If null the batchers shader is used.
     */
    public var shader (default, set) : ShaderResource;

    inline function set_shader(_shader : ShaderResource) : ShaderResource {
        events.fire(OrderProperyChanged);

        return shader = _shader;
    }

    /**
     * The depth of this mesh within the batcher.
     */
    public var depth (default, set) : Float;

    inline function set_depth(_depth : Float) : Float {
        events.fire(OrderProperyChanged);

        return depth = _depth;
    }

    /**
     * The primitive type of this geometry.
     */
    public var primitive (default, set) : PrimitiveType;

    inline function set_primitive(_primitive : PrimitiveType) : PrimitiveType {
        events.fire(OrderProperyChanged);

        return primitive = _primitive;
    }

    /**
     * If immediate this geometry will only be drawn once.
     */
    public var immediate : Bool;

    /**
     * If this geometry will not be changing. Provides a hint to the backend on how to optimise this geometry.
     */
    public var unchanging : Bool;

    /**
     * Default colour of this geometry.
     */
    public var color : Color;

    /**
     * The position of the geometry.
     */
    public var position (get, never) : Vector;

    inline function get_position() : Vector {
        return transformation.position;
    }

    /**
     * The origin of the geometry.
     */
    public var origin (get, never) : Vector;

    inline function get_origin() : Vector {
        return transformation.origin;
    }

    /**
     * Rotation of the geometry.
     */
    public var rotation (get, never) : Quaternion;

    inline function get_rotation() : Quaternion {
        return transformation.rotation;
    }

    /**
     * Scale of the geometry.
     */
    public var scale (get, never) : Vector;

    inline function get_scale() : Vector {
        return transformation.scale;
    }

    /**
     * All of the batchers this geometry is in.
     */
    final batchers : Array<Batcher>;

    /**
     * Create a new mesh, contains no vertices and no transformation.
     */
    public function new(_options : GeometryOptions)
    {
        id     = Hash.uniqueHash();
        events = new EventBus();

        shader         = _options.shader;
        vertices       = def(_options.vertices  , []);
        transformation = def(_options.transform , inline new Transformation());
        clip           = def(_options.clip      , inline new Rectangle());
        textures       = def(_options.textures  , []);
        depth          = def(_options.depth     , 0);
        unchanging     = def(_options.unchanging, false);
        immediate      = def(_options.immediate , false);
        primitive      = def(_options.primitive , Triangles);
        color          = def(_options.color     , inline new Color());
        blend          = def(_options.blend     , inline new Blending());
        batchers       = def(_options.batchers  , []);

        // Add to batchers.
        for (batcher in batchers)
        {
            batcher.addGeometry(this);
        }
    }

    /**
     * Add a vertex to this mesh.
     * @param _v Vertex to add.
     */
    public function addVertex(_v : Vertex)
    {
        vertices.push(_v);
    }

    /**
     * Remove a vertex from this mesh.
     * @param _v Vertex to remove.
     */
    public function removeVertex(_v : Vertex)
    {
        vertices.remove(_v);
    }

    /**
     * Remove this geometry from all the batchers it is in.
     */
    public function drop()
    {
        for (batcher in batchers)
        {
            batcher.removeGeometry(this);
        }

        batchers.resize(0);
    }
}
