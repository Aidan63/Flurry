package uk.aidanlee.gpu.geometry;

import snow.api.Emitter;
import snow.api.Debug.def;
import uk.aidanlee.gpu.Shader;
import uk.aidanlee.gpu.batcher.Batcher;
import uk.aidanlee.maths.Vector;
import uk.aidanlee.maths.Rectangle;

enum PrimitiveType {
    Points;
    Lines;
    LineStrip;
    Triangles;
    TriangleStrip;
}

enum BlendMode {
    Zero;
    One;
    SrcAlphaSaturate;

    SrcColor;
    OneMinusSrcColor;
    SrcAlpha;
    OneMinusSrcAlpha;
    DstAlpha;
    OneMinusDstAlpha;
    DstColor;
    OneMinusDstColor;
}

enum abstract EvGeometry(Int) from Int to Int {
    var OrderProperyChanged;
}

typedef GeometryOptions = {
    var ?name       : String;
    var ?shader     : Shader;
    var ?textures   : Array<Texture>;
    var ?depth      : Int;
    var ?immediate  : Bool;
    var ?unchanging : Bool;
    var ?color      : Color;
    var ?clip       : Rectangle;
    var ?primitive  : PrimitiveType;
    var ?batchers   : Array<Batcher>;

    var ?blending : Bool;
    var ?srcRGB   : BlendMode;
    var ?dstRGB   : BlendMode;
    var ?srcAlpha : BlendMode;
    var ?dstAlpha : BlendMode;
}

/**
 * Geometry class, holds a set of verticies and a matrix transformation for them.
 */
class Geometry
{
    /**
     * Name of this geometry.
     * This name is used as part of a hash key for batching unchanging geometry.
     * If this geometry is unchanging its name should be unique.
     */
    public final name : String;

    /**
     * Fires various events about the geometry.
     */
    public final events : Emitter<EvGeometry>;

    /**
     * This meshes vertices.
     */
    public final vertices : Array<Vertex>;

    /**
     * Transformation of this geometry.
     */
    public final transformation : Transformation;

    /**
     * ID of the texture this mesh uses.
     */
    public final textures : Array<Texture>;

    /**
     * The specific shader for the geometry.
     * If null the batchers shader is used.
     */
    public var shader (default, set) : Shader;

    inline public function set_shader(_shader : Shader) : Shader {
        events.emit(OrderProperyChanged);

        return shader = _shader;
    }

    /**
     * The depth of this mesh within the batcher.
     */
    public var depth (default, set) : Float;

    inline public function set_depth(_depth : Float) : Float {
        events.emit(OrderProperyChanged);

        return depth = _depth;
    }

    /**
     * Clipping rectangle for this geometry. Null if none.
     */
    public var clip (default, set) : Rectangle;

    inline public function set_clip(_clip : Rectangle) : Rectangle {
        events.emit(OrderProperyChanged);

        return clip = _clip;
    }

    /**
     * The primitive type of this geometry.
     */
    public var primitive (default, set) : PrimitiveType;

    inline public function set_primitive(_primitive : PrimitiveType) : PrimitiveType {
        events.emit(OrderProperyChanged);

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
     * If blending is enabled for this geometry.
     */
    public var blending : Bool;

    /**
     * The source colour for blending.
     */
    public var srcRGB : BlendMode;

    /**
     * The source alpha for blending.
     */
    public var srcAlpha : BlendMode;

    /**
     * The destination color for blending.
     */
    public var dstRGB : BlendMode;

    /**
     * The destination alpha for blending.
     */
    public var dstAlpha : BlendMode;

    /**
     * Create a new mesh, contains no vertices and no transformation.
     */
    public function new(_options : GeometryOptions)
    {
        events = new Emitter();

        vertices       = [];
        transformation = new Transformation();

        shader     = _options.shader;
        clip       = _options.clip;
        textures   = def(_options.textures  , []);
        name       = def(_options.name      , '');
        depth      = def(_options.depth     , 0);
        unchanging = def(_options.unchanging, false);
        immediate  = def(_options.immediate , false);
        primitive  = def(_options.primitive , Triangles);
        color      = def(_options.color     , new Color());

        // Setup blending
        blending = def(_options.blending, true);
        srcRGB   = def(_options.srcRGB  , SrcAlpha);
        srcAlpha = def(_options.srcAlpha, One);
        dstRGB   = def(_options.dstRGB  , OneMinusSrcAlpha);
        dstAlpha = def(_options.dstAlpha, Zero);

        // If the geometry is unchanging its name cannot be an empty string
        if (unchanging && name == '')
        {
            throw 'Geometry Exception : Unchanging geometry cannot have an empty string as a name';
        }

        // Add to batchers.
        for (batcher in def(_options.batchers, []))
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
     * Set the world space position of this mesh.
     * 
     * The verticies themselves are not updated. The transformation matrix is applied to them when batched into a buffer.
     * @param _v Vector containing the x, y, and z position.
     * @return Mesh
     */
    public function setPosition(_v : Vector) : Geometry
    {
        transformation.position.set_xyz(_v.x, _v.y, _v.z);

        return this;
    }

    /**
     * Sets the scale of this mesh.
     * 
     * The verticies themselves are not updated. The transformation matrix is applied to them when batched into a buffer.
     * @param _v Vector containing the x, y, and z scale.
     * @return Mesh
     */
    public function setScale(_v : Vector) : Geometry
    {
        transformation.scale.set_xyz(_v.x, _v.y, _v.z);

        return this;
    }
}
